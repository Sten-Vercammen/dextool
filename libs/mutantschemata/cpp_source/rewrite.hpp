//------------------------------------------------------------------------------
// Mutant schemata using Clang rewriter and RecursiveASTVisitor
//
// Sten Vercammem (sten.vercammen@uantwerpen.be)
//------------------------------------------------------------------------------

#include <set>
#include <sstream>
#include <vector>
#include <fstream>

#include "clang/AST/AST.h"
#include "clang/AST/ASTContext.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/Frontend/ASTConsumers.h"
#include "clang/Frontend/FrontendActions.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Tooling/CommonOptionsParser.h"
#include "clang/Tooling/Tooling.h"
#include "clang/Rewrite/Core/Rewriter.h"

#ifndef MS_CLANG_REWRITE
#define MS_CLANG_REWRITE


// defines to control what happens \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
#define debugDuplicateMutantPrevention
// config mutant schemata (not really implemented)
bool negateBinaryOperators = true;
bool negateOverloadedOperators = false;
bool negateUnaryOperators = false;
///////////////////////////////////////////////////////////////////////////////|


// global clang vars \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
clang::Rewriter rewriter;
clang::SourceManager *SourceManager;
///////////////////////////////////////////////////////////////////////////////|


// variables need to uniquely insert meta-mutants \\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
std::vector<std::string> SourcePaths;
std::set<std::string> VisitedSourcePaths;
int mutant_count = 1;

struct InsertedMutant {
    const clang::FileEntry *fE; // needed to calc FID
    unsigned exprOffs;
    unsigned bracketsOffs;
    
    InsertedMutant(const clang::FileEntry *f, unsigned int s, unsigned int e): fE(f), exprOffs(s), bracketsOffs(e) {}
};
struct MutantInsert {
    InsertedMutant* mutantLoc;
    std::string expr;
    std::string brackets;
    
    MutantInsert(InsertedMutant* m, std::string e, std::string b): mutantLoc(m), expr(e), brackets(b) {}
};

std::vector<MutantInsert*> mutantInserts;
// custom comperator for mutants based on their FileID (FileEntry) and location (offsets)
struct mutantLocComp {
    bool operator() (const MutantInsert *lhs, const MutantInsert *rhs) const {
        if (lhs->mutantLoc->fE == rhs->mutantLoc->fE) {
            if (lhs->mutantLoc->exprOffs == rhs->mutantLoc->exprOffs) {
                return lhs->mutantLoc->bracketsOffs < rhs->mutantLoc->bracketsOffs;
            }
            return lhs->mutantLoc->exprOffs < rhs->mutantLoc->exprOffs;
        }
        return lhs->mutantLoc->fE < rhs->mutantLoc->fE;
    }
};
// keep an ordered set of the created mutants to prevent duplicates
// TODO optimise: 1 per file, only overwrite when new mutants were added
std::set<MutantInsert*, mutantLocComp> insertedMutants;
///////////////////////////////////////////////////////////////////////////////|


// needed functionality not (publically) available in clang \\\\\\\\\\\\\\\\\\\|
/**
 * Return true if this character is non-new-line whitespace:
 * ' ', '\\t', '\\f', '\\v', '\\r'.
 */
static inline bool isWhitespaceExceptNL(unsigned char c) {
    switch (c) {
        case ' ':
        case '\t':
        case '\f':
        case '\v':
        case '\r':
            return true;
        default:
            return false;
    }
}

class MutantRewriter: public clang::Rewriter {
public:
    bool InsertText(const clang::FileEntry *fE, unsigned StartOffs, StringRef Str, bool InsertAfter = true, bool indentNewLines = false) {
        clang::FileID FID = this->getSourceMgr().translateFile(fE);
        if (!FID.getHashValue()) {
            FID = this->getSourceMgr().createFileID(fE, clang::SourceLocation(), clang::SrcMgr::CharacteristicKind::C_User);
        }

        llvm::SmallString<128> indentedStr;
        if (indentNewLines && Str.find('\n') != StringRef::npos) {
            StringRef MB = this->getSourceMgr().getBufferData(FID);
            
            unsigned lineNo = this->getSourceMgr().getLineNumber(FID, StartOffs) - 1;
            const clang::SrcMgr::ContentCache *Content = this->getSourceMgr().getSLocEntry(FID).getFile().getContentCache();
            unsigned lineOffs = Content->SourceLineCache[lineNo];
            
            // Find the whitespace at the start of the line.
            StringRef indentSpace;
            {
                unsigned i = lineOffs;
                while (isWhitespaceExceptNL(MB[i]))
                    ++i;
                indentSpace = MB.substr(lineOffs, i-lineOffs);
            }
            
            llvm::SmallVector<StringRef, 4> lines;
            Str.split(lines, "\n");
            
            for (unsigned i = 0, e = lines.size(); i != e; ++i) {
                indentedStr += lines[i];
                if (i < e-1) {
                    indentedStr += '\n';
                    indentedStr += indentSpace;
                }
            }
            Str = indentedStr.str();
        }
        
        getEditBuffer(FID).InsertText(StartOffs, Str, InsertAfter);
        return false;
    }
};

clang::SourceLocation getFileLocSlowCase(clang::SourceLocation Loc) {
    do {
        if (SourceManager->isMacroArgExpansion(Loc))
            Loc = SourceManager->getImmediateSpellingLoc(Loc);
        else
            //TODO in later versions of clang this doesn't return a pair, but the CharSourceRange class (we should then use .begin())
            Loc = SourceManager->getImmediateExpansionRange(Loc).first;
    } while (!Loc.isFileID());
    return Loc;
}

clang::SourceLocation getFileLoc(clang::SourceLocation Loc) {
    if (Loc.isFileID()) return Loc;
    return getFileLocSlowCase(Loc);
}

/**
 * Calculates offset of location, optionally increased with the range of the last token
 * Returns true on failure
 */
bool calculateOffsetLoc(clang::SourceLocation Loc, const clang::FileEntry *&fE, unsigned &offset, bool afterToken = false) {
    // make sure we use the correct Loc, MACRO's needs to be tracked back to their spelling location
    Loc = getFileLoc(Loc);
    if (!clang::Rewriter::isRewritable(Loc)) {
        llvm::errs() << "not rewritable !!!!!\n";
        return true;
    }
    assert(Loc.isValid() && "Invalid location");
    /*
     * Get FileID and offset from the Location.
     * Offset is the offset in the file, so this is a "constant".
     * FileID's can change depending on the order of opening, so we can't trust this.
     * We'll store the FileEntry and infer the FileID from it when we need it.
     */
    std::pair<clang::FileID, unsigned> V = SourceManager->getDecomposedLoc(Loc);
    clang::FileID FID = V.first;
    fE = SourceManager->getFileEntryForID(FID);
    offset = V.second;
    
    if (afterToken) {
        // we want the offset after the last token, so we need to calculate the range of the last token
        clang::Rewriter::RewriteOptions rangeOpts;
        rangeOpts.IncludeInsertsAtBeginOfRange = false;
        offset += rewriter.getRangeSize(clang::SourceRange(Loc, Loc), rangeOpts);
    }
    return false;
}
///////////////////////////////////////////////////////////////////////////////|

// functionality to write changed files to disk \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
/**
 * Write the modified AST to files.
 * Either in place, or with suffix _mutated
 *
 * Note: use false, as inPlace causes a sementation fault in clang's sourcemaneger calling the ComputeLineNumbers function, when used in the EndSourceFileAction.
 * Caling rewriter.overwriteChangedFiles() after Tool.run causes a segmentation fault as some rewrite buffers are already deconstructed.
 * This is why we need to use temp files.
 */
void writeChangedFiles(bool inPlace) {
    if (inPlace) {
        rewriter.overwriteChangedFiles();
    } else {
        /*
         * iterate through rewrite buffer
         *
         * Note: when a (system) file is visited without being mutated,
         * then it will currently also turn up here (as an editBuffer was created for it)
         */
        for (std::map<clang::FileID, clang::RewriteBuffer>::iterator I = rewriter.buffer_begin(), E = rewriter.buffer_end(); I != E; ++I) {
            const clang::FileEntry *file = rewriter.getSourceMgr().getFileEntryForID(I->first);
            if (file) {
                if (file->isValid()) {
                    bool isSourceFile = false;
                    // check if the edited file is one we wanted to mutate
                    // (technically we are only changing files in SourcePaths, but somehow other files still show up in the editbuffer)
                    for (std::string item: SourcePaths) {
                        // are sourceFile and bufferFile equivalent (same path, takes into account different relative paths)
                        if (llvm::sys::fs::equivalent(item, file->tryGetRealPathName())) {
                            isSourceFile = true;
                            break;
                        }
                    }
                    
                    if (isSourceFile) {
                        // Mark changed file as visited, so we know it was changed.
                        VisitedSourcePaths.insert(file->tryGetRealPathName());
                        
                        // include to define identifier
                        // note: main file should contain the actual declaration (without extern)
                        const char *include = "extern int MUTANT_NR;\n";
                        I->second.InsertTextAfter(0, include);
                        
                        // write what's in the buffer to a temporary file
                        // placed here to prevent writing the mutated file multiple times
                        std::error_code error_code;
                        std::string fileName = file->getName().str() + "_mutated_" + std::to_string(mutant_count);
//                        std::string fileName = file->getName().str() + "_mutated";
                        llvm::raw_fd_ostream outFile(fileName, error_code, llvm::sys::fs::F_None);
                        outFile << std::string(I->second.begin(), I->second.end());
                        outFile.close();
                        
                        // debug output
                        llvm::errs() << "Mutated file: " << file->getName().str() << "\n";
                    }
                }
            } else {
                // not an actual file
            }
        }
    }
}

/**
 * function that adds definition of MUTANT_NR to main file,
 * or removes the extern keyword if the file was mutated.
 */
void fixMainFile(std::string pathToMainFile) {
    const char *possible_include = "extern int MUTANT_NR;";
    const char *fix_include = "      "; // only override the extern keyword with spaces, this prevents us from needing to copy and write the complete file
    
    std::fstream ifs;
    ifs.open(pathToMainFile, std::ios::in | std::ios::out);
    
    // check if the file is open
    if (ifs) {
        std::string line;
        if (getline(ifs, line)) {
            // point back to the beginning of the file
            ifs.seekp(0);
            
            // if first line is equal
            if (strcmp(possible_include, line.c_str()) == 0) {
                // override extern keword with spaces
                ifs << fix_include;
            } else { // file didn't contain our MUTANT_NR include
                // store entire file in buffer
                std::stringstream buffer;
                buffer << ifs.rdbuf();
                // point back to the beginning of the file
                ifs.seekp(0);
                // write the MUTANT_NR;
                ifs << "       int MUTANT_NR;\n";
                // write our buffer
                ifs << buffer.str();
            }
        }
    } else {
        llvm::errs() << "unable to open main file\n";
    }
    ifs.close();
}


/**
 * write the temporary files over the original ones
 */
void overWriteChangedFile() {
    for (std::string fileName: VisitedSourcePaths) {
        // deletes the old file
        std::string oldFileName = fileName + "_mutated";
        if (std::rename(oldFileName.c_str(), fileName.c_str()) != 0) {
            std::perror("Error renaming file");
        }
    }
}
///////////////////////////////////////////////////////////////////////////////|

// actual clang functions to traverse AST \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\|
class MutatingVisitor : public clang::RecursiveASTVisitor<MutatingVisitor> {
private:
    clang::ASTContext *astContext;
    clang::PrintingPolicy pp;
    
    void insertMutantSchemata(clang::BinaryOperator *binOp, std::initializer_list<clang::BinaryOperatorKind> list) {
        // get lhs of expression
        std::string lhs;
        llvm::raw_string_ostream lhs_expr_stream(lhs);
        binOp->getLHS()->printPretty(lhs_expr_stream, nullptr, pp);
        lhs_expr_stream.flush();
        
        // get rhs of expression
        std::string rhs;
        llvm::raw_string_ostream rhs_expr_stream(rhs);
        binOp->getRHS()->printPretty(rhs_expr_stream, nullptr, pp);
        rhs_expr_stream.flush();
        
        // get expression with mutant schemata
        std::stringstream newExprStr;
        std::string endBrackets;
        for (auto elem : list) {
            if (binOp->getOpcode() != elem) {
                //                newExprStr << "(MUTANT_NR == " << mutant_count++ <<" ? " << lhs << " " << clang::BinaryOperator::getOpcodeStr(elem).str() << " " << rhs << ": ";
                newExprStr << " ? " << lhs << " " << clang::BinaryOperator::getOpcodeStr(elem).str() << " " << rhs << ": ";
                endBrackets += ")";
            }
        }
        
        // calculate offset and FileEntry (we don;t use FileID as this can change depending on the order of opening files etc.)
        const clang::FileEntry *fE;
        unsigned exprOffs, bracketsOffs;
        calculateOffsetLoc(binOp->getLocStart(), fE, exprOffs);
        calculateOffsetLoc(binOp->getLocEnd(), fE, bracketsOffs, true);
        
        // create and store the created (meta-) mutant
        InsertedMutant *im = new InsertedMutant(fE, exprOffs, bracketsOffs);
        MutantInsert *mi = new MutantInsert(im, newExprStr.str(), endBrackets);

        std::set<MutantInsert*, mutantLocComp>::iterator it = insertedMutants.find(mi);
        if (it == insertedMutants.end()) {
            mutantInserts.push_back(mi);
            insertedMutants.insert(mi);
//            llvm::errs() << "inserted mutant: " << mi->expr << "\n";
            mutant_count++; //increase count as we are sure it isn't a duplicated vallid mutant
        } else {
#ifdef debugDuplicateMutantPrevention
            // TODO verify that the actual mutation is the same, print error when it's not
            if ((*it)->expr.compare(mi->expr) != 0) {
                llvm::errs() << "found a bug: duplicated mutant isn't the same:\nfound: " << (*it)->expr << "\nexpected: "<< mi->expr << "\n";
            }
#endif
        }
        
        
       // llvm::errs() << "found a mutant\n";
    }
    
    /**
     * Check if we want to mutate this file.
     * (if it's a sourceFile and we haven't yet visited it)
     */
    bool isfileToMutate(clang::FullSourceLoc FullLocation) {
        const clang::FileEntry *fE = SourceManager->getFileEntryForID(SourceManager->getFileID(FullLocation));
        if (fE) {
            for (std::string item: SourcePaths) {
                if (llvm::sys::fs::equivalent(item, fE->tryGetRealPathName())) {
                    return true;
                    //                    return VisitedSourcePaths.find(fE->tryGetRealPathName()) == VisitedSourcePaths.end();
                }
            }
        }
        return false;
    }
    
    
public:
    explicit MutatingVisitor(clang::CompilerInstance *CI): astContext(&(CI->getASTContext())), pp(astContext->getLangOpts()) {
        SourceManager = &astContext->getSourceManager();
    }
    
    virtual bool VisitStmt(clang::Stmt *s) {
        clang::FullSourceLoc FullLocation = astContext->getFullLoc(s->getLocStart());
        if (!isfileToMutate(FullLocation)) {
            return true;
        }
        
        // mutate all expressions
        if (clang::isa<clang::Expr>(s)) {
            if (clang::isa<clang::BinaryOperator>(s)) {
                clang::BinaryOperator *binOp = clang::cast<clang::BinaryOperator>(s);
                if (negateBinaryOperators) {
                    switch (binOp->getOpcode()) {
                            // Multiplicative operators
#ifndef onlyAddSub
                        case clang::BO_Mul:
                            insertMutantSchemata(binOp, {clang::BO_Div});
                            break;
                        case clang::BO_Div:
                            insertMutantSchemata(binOp, {clang::BO_Mul});
                            break;
                        case clang::BO_Rem:
                            //TODO
                            break;
                            // Additive operators
#endif
                        case clang::BO_Add:
                            insertMutantSchemata(binOp, {clang::BO_Sub});
                            break;
                        case clang::BO_Sub:
                            insertMutantSchemata(binOp, {clang::BO_Add});
                            break;
#ifndef onlyAddSub
                            // Bitwise shift operators
                        case clang::BO_Shl:
                            insertMutantSchemata(binOp, {clang::BO_Shr});
                            break;
                        case clang::BO_Shr:
                            insertMutantSchemata(binOp, {clang::BO_Shl});
                            break;
                            // Three-way comparison operator
                            //case clang::BO_Cmp:
                            //TODO
                            //    break;
                            // Relational operators
                        case clang::BO_LT:
                            insertMutantSchemata(binOp, {clang::BO_GT});
                            break;
                        case clang::BO_GT:
                            insertMutantSchemata(binOp, {clang::BO_LT});
                            break;
                        case clang::BO_LE:
                            insertMutantSchemata(binOp, {clang::BO_GE});
                            break;
                        case clang::BO_GE:
                            insertMutantSchemata(binOp, {clang::BO_LE});
                            break;
                            // Equality operators
                        case clang::BO_EQ:
                            insertMutantSchemata(binOp, {clang::BO_NE});
                            break;
                        case clang::BO_NE:
                            insertMutantSchemata(binOp, {clang::BO_EQ});
                            break;
                            // Bitwise AND operator
                        case clang::BO_And:
                            insertMutantSchemata(binOp, {clang::BO_Or});
                            break;
                        case clang::BO_Xor:
                            //TODO
                            break;
                        case clang::BO_Or:
                            insertMutantSchemata(binOp, {clang::BO_And});
                            break;
                            // Logical AND operator
                        case clang::BO_LAnd:
                            insertMutantSchemata(binOp, {clang::BO_LOr});
                            break;
                        case clang::BO_LOr:
                            insertMutantSchemata(binOp, {clang::BO_LAnd});
                            break;
                            // Assignment operators
                        case clang::BO_Assign:
                            //TODO
                            break;
                        case clang::BO_MulAssign:
                            insertMutantSchemata(binOp, {clang::BO_DivAssign});
                            break;
                        case clang::BO_DivAssign:
                            insertMutantSchemata(binOp, {clang::BO_MulAssign});
                            break;
                        case clang::BO_RemAssign:
                            //TODO
                            break;
                        case clang::BO_AddAssign:
                            insertMutantSchemata(binOp, {clang::BO_SubAssign});
                            break;
                        case clang::BO_SubAssign:
                            insertMutantSchemata(binOp, {clang::BO_AddAssign});
                            break;
                        case clang::BO_ShlAssign:
                            insertMutantSchemata(binOp, {clang::BO_ShrAssign});
                            break;
                        case clang::BO_ShrAssign:
                            insertMutantSchemata(binOp, {clang::BO_ShlAssign});
                            break;
                        case clang::BO_AndAssign:
                            insertMutantSchemata(binOp, {clang::BO_OrAssign});
                            break;
                        case clang::BO_XorAssign:
                            //TODO
                            break;
                        case clang::BO_OrAssign:
                            insertMutantSchemata(binOp, {clang::BO_AndAssign});
                            break;
#endif
                        default:
                            break;
                    }
                } else if (negateUnaryOperators) {
                    //TODO
                } else if (false) {
                    if (binOp->isPtrMemOp()) {
                        
                        
                    } else if (binOp->isMultiplicativeOp()) {   // clang::BO_Mul, clang::BO_Div, clang::BO_Rem
                        insertMutantSchemata(binOp, {clang::BO_Mul, clang::BO_Div, clang::BO_Rem});
                    } else if (binOp->isAdditiveOp()) {         // clang::BO_Add, clang::BO_Sub
                        insertMutantSchemata(binOp, {clang::BO_Add, clang::BO_Sub});
                    } else if (binOp->isShiftOp()) {            // clang::BO_Shl, clang::BO_Shr
                        insertMutantSchemata(binOp, {clang::BO_Shl, clang::BO_Shr});
                    } else if (binOp->isBitwiseOp()) {          // clang::BO_And, clang::BO_Xor, clang::BO_Or
                        insertMutantSchemata(binOp, {clang::BO_And, clang::BO_Xor, clang::BO_Or});
                    } else if (binOp->isRelationalOp()) {       // clang::BO_LT, clang::BO_GT, clang::BO_LE, clang::BO_GE
                        insertMutantSchemata(binOp, {clang::BO_LT, clang::BO_GT, clang::BO_LE, clang::BO_GE});
                    } else if (binOp->isEqualityOp()) {         // clang::BO_EQ, clang::BO_NE
                        insertMutantSchemata(binOp, {clang::BO_EQ, clang::BO_NE});
                    } else if (binOp->isComparisonOp()) {       // clang::BO_Cmp, isEqualityOp, isRelationalOp
                        insertMutantSchemata(binOp, {clang::BO_EQ, clang::BO_LT, clang::BO_GT, clang::BO_LE, clang::BO_GE, clang::BO_NE});
                    } else if (binOp->isLogicalOp()) {          // clang::BO_LAnd, clang::BO_LOr
                        insertMutantSchemata(binOp, {clang::BO_LAnd, clang::BO_LOr});
                    } else if (binOp->isAssignmentOp()) {       // clang::BO_Assign, clang::BO_MulAssign, clang::BO_DivAssign, clang::BO_RemAssign, clang::BO_AddAssign, clang::BO_SubAssign, clang::BO_ShlAssign, clang::BO_ShrAssign, clang::BO_AndAssign, clang::BO_XorAssign, clang::BO_OrAssign
                        insertMutantSchemata(binOp, {clang::BO_Assign, clang::BO_MulAssign, clang::BO_DivAssign, clang::BO_RemAssign, clang::BO_AddAssign, clang::BO_SubAssign, clang::BO_ShlAssign, clang::BO_ShrAssign, clang::BO_AndAssign, clang::BO_XorAssign, clang::BO_OrAssign});
                    } else if (binOp->isCompoundAssignmentOp()) {   // clang::BO_MulAssign, clang::BO_DivAssign, clang::BO_RemAssign, clang::BO_AddAssign, clang::BO_SubAssign, clang::BO_ShlAssign, clang::BO_ShrAssign, clang::BO_AndAssign, clang::BO_XorAssign, clang::BO_OrAssign
                        insertMutantSchemata(binOp, {clang::BO_MulAssign, clang::BO_DivAssign, clang::BO_RemAssign, clang::BO_AddAssign, clang::BO_SubAssign, clang::BO_ShlAssign, clang::BO_ShrAssign, clang::BO_AndAssign, clang::BO_XorAssign, clang::BO_OrAssign});
                    } else if (binOp->isShiftAssignOp()) {      // clang::BO_ShlAssign, clang::BO_ShrAssign
                        insertMutantSchemata(binOp, {clang::BO_ShlAssign, clang::BO_ShrAssign});
                    }
                }
            } else if (clang::isa<clang::CXXOperatorCallExpr>(s)) {
                if (negateOverloadedOperators) {
                    clang::CXXOperatorCallExpr *oExpr = clang::cast<clang::CXXOperatorCallExpr>(s);
                    
                    clang::OverloadedOperatorKind oOp = oExpr->getOperator();
                    if (oOp == clang::OO_Plus) {
                        printf("found CXXOperatorCallExpr expr of Addition in %s\n", oExpr->getStmtClassName());
                        //TODO check if this is really the place where the oOp is declared
                        clang::FunctionDecl *dDecl = oExpr->getDirectCallee();
                        if (dDecl == nullptr) {
                            llvm::errs() << "Overloaded operator is not a functionDecl -> paradox";
                            exit(-1);
                        }
                        clang::FunctionDecl *def = dDecl->getDefinition();
                        if (def == nullptr) {
                            printf("definition is nullptr???\n");
                            exit(1);
                        }
                        def->dump();
                        if (!def->isOverloadedOperator()) {
                            printf("overloaded operator is not an overloaded operator -> paradox");
                            exit(1);
                        }
                        clang::DeclContext *dCtx = def->getParent();
                        if (dCtx == NULL) {
                            printf("decl context is null :(\n");
                            exit(1);
                        }
                        printf("\ndumpLookups\n\n");
                        //dCtx->dumpDeclContext();
                        dCtx->dumpLookups();
                        if (dCtx) {
                            printf("declCtx != null\n");
                            for (auto it = dCtx->decls_begin(); it != dCtx->decls_end(); ++it) {
                                clang::FunctionDecl *funcDecl = (*it)->getAsFunction();
                                if (funcDecl != NULL && funcDecl != def) {
                                    if (funcDecl->isOverloadedOperator()) {
                                        printf("its an overloaded operator!!! :O \n");
                                    }
                                    if (funcDecl->getReturnType() == def->getReturnType()) {
                                        printf("is this the other one?\n");
                                    }
                                } else {
                                    printf("nope, it's not a funcDecl\n");
                                }
                                //                            clang::Stmt *func = (*it)->getBody();
                                //                            if (func) {
                                //                                printf("exists\n");
                                //                                func->dump();
                                //                                func
                                //                                if (clang::isa<CXXOperatorCallExpr>(func)) {
                                //                                    CXXOperatorCallExpr *oExprOther = clang::cast<CXXOperatorCallExpr>(func);
                                //                                    printf("it's also a operator\n");
                                //                                    OverloadedOperatorKind oOpOther = oExprOther->getOperator();
                                //                                    if (oOpOther == OO_Plus) {
                                //                                        printf("and yes, its an CXXOperatorCallExpr expr of Addition in %s\n", oExprOther->getStmtClassName());
                                //                                    }
                                //                                }
                                //                            }
                            }
                        } else {
                            printf("declCtx == null\n");
                        }
                        //                    DeclContext *declCtx = decl->getDeclContext();   // semantical context (not lexical)
                        
                        
                        // TODO check this in a better way, we must find the symbol table
                        // as an operator does not have to be overloaded in the same file
                        // or in the class intself
                        // either check the symbol table, or also check the global space
                    } else {
                        printf("found CXXOperatorCallExpr expr of another kind\n");
                    }
                    exit(1);
                }
            }
        }
        return true;
    }
};



class MutationConsumer : public clang::ASTConsumer {
private:
    MutatingVisitor *visitor;
    
public:
    // override in order to pass CI to custom visitor
    explicit MutationConsumer(clang::CompilerInstance *CI): visitor(new MutatingVisitor(CI)) {}
    
    // override to call our custom visitor on the entire source file
    // Note we do this with TU as then the file is parsed, with TopLevelDecl, it's parsed whilst iterating
    virtual void HandleTranslationUnit(clang::ASTContext &Context) {
        // we can use ASTContext to get the TranslationUnitDecl, which is
        // a single Decl that collectively represents the entire source file
        visitor->TraverseDecl(Context.getTranslationUnitDecl());
    }
    
    
    //     // override to call our custom visitor on each top-level Decl
    //     virtual bool HandleTopLevelDecl(clang::DeclGroupRef DG) {
    //     // a DeclGroupRef may have multiple Decls, so we iterate through each one
    //     for (clang::DeclGroupRef::iterator i = DG.begin(), e = DG.end(); i != e; i++) {
    //     clang::Decl *D = *i;
    //     visitor->TraverseDecl(D); // recursively visit each AST node in Decl "D"
    //     }
    //     return true;
    //     }
    
};


class MutationFrontendAction : public clang::ASTFrontendAction {
public:
    virtual std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &CI, StringRef file) {
        // the same file can be analysed multiple times as it is possible that in one project it needs to be compiled multiple times with different flags
        llvm::errs() << "Starting to mutate the following file and all of it's includes: " << file << "\n";
        rewriter = clang::Rewriter();
        rewriter.setSourceMgr(CI.getSourceManager(), CI.getLangOpts());
        return std::unique_ptr<clang::ASTConsumer> (new MutationConsumer(&CI)); // pass CI pointer to ASTConsumer
    }
    
    virtual void EndSourceFileAction() {
        int localMutantCount = 1;
        for (MutantInsert *mi: mutantInserts) {
            // insert mutant before orig expression
            MutantRewriter *r = (MutantRewriter*)(&rewriter);
            //mi->mutantLoc->startExpr, mi->expr);
            r->InsertText(mi->mutantLoc->fE, mi->mutantLoc->exprOffs, "(MUTANT_NR == " + std::to_string(localMutantCount++) + mi->expr);
            // insert brackets to close mutant schemata's if statement
            r->InsertText(mi->mutantLoc->fE, mi->mutantLoc->bracketsOffs, mi->brackets, true);
        }
        writeChangedFiles(false);
    }
};


// Apply a custom category to all command-line options so that they are the only ones displayed.
static llvm::cl::OptionCategory MutantShemataCategory("mutation-schemata options");


/**
 * Expecting: argv: -p ../googletest/build filePathToMutate1 filePathToMutate2 ...
 */
int setupClang(int argc, const char **argv) {
    // parse the command-line args passed to your code
    clang::tooling::CommonOptionsParser op(argc, argv, MutantShemataCategory);
    
    // store all paths to mutate, but fix to absolute path
    for (std::string item: op.getSourcePathList()) {
        SourcePaths.push_back(clang::tooling::getAbsolutePath(item));
    }
    
    // create a new Clang Tool instance (a LibTooling environment)
    clang::tooling::ClangTool Tool(op.getCompilations(), op.getSourcePathList());
    
    // run the Clang Tool, creating a new FrontendAction
    int result = Tool.run(clang::tooling::newFrontendActionFactory<MutationFrontendAction>().get());
    
    /*
     * move newly created files onto the old files
     * Caling rewriter.overwriteChangedFiles() here causes a segmentation fault
     * as some rewrite buffers are already deconstructed.
     * Calling it in the EndSourceFileAction causes a sementation fault
     * in clang's sourcemaneger calling the ComputeLineNumbers function.
     * This is why we need to use temp files.
     */
    overWriteChangedFile();
    
    llvm::errs() << "\nMutations found: " << mutant_count - 1 << "\n";
    
    return result;
}
///////////////////////////////////////////////////////////////////////////////|
#endif // MS_CLANG_REWRITE

