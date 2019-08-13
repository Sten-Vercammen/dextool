//------------------------------------------------------------------------------
// Mutant schemata using Clang rewriter and RecursiveASTVisitor
//
// Sten Vercammem (sten.vercammen@uantwerpen.be)
//------------------------------------------------------------------------------

#include <set>
#include <sstream>
#include <vector>

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


// global vars
clang::Rewriter rewriter;
std::vector<std::string> SourcePaths;
std::set<std::string> VisitedSourcePaths;
int mutant_count = 1;

// config mutant schemata (not really implemented)
bool negateBinaryOperators = true;
bool negateOverloadedOperators = false;
bool negateUnaryOperators = false;

// preventig duplicate writung of already analysed files
// TODO optimisations should be possible
std::string processingFile;
bool written = false;


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
                        /*
                         * Mark changed file as visited, so we don't mutate it again later.
                         * Needed as inserted mutants are new, unvisited nodes in the AST,
                         * and we don't want to mutate them.
                         */
                        std::set<std::string>::iterator it = VisitedSourcePaths.find(file->tryGetRealPathName());
                        if (it == VisitedSourcePaths.end()) {
                            VisitedSourcePaths.insert(file->tryGetRealPathName());
                            
                            // include to define identifier
                            // note: main file should contain the actual declaration (without extern)
                            const char *include = "extern int MUTANT_NR;\n";
                            I->second.InsertTextAfter(0, include);
			    
                            // write what's in the buffer to a temporary file
                            // placed here to prevent writing the mutated file multiple times
                            std::error_code error_code;
                            std::string fileName = file->getName().str() + "_mutated";
                            llvm::raw_fd_ostream outFile(fileName, error_code, llvm::sys::fs::F_None);
                            outFile << std::string(I->second.begin(), I->second.end());
                            outFile.close();
                            
                            // debug output
                            llvm::errs() << "Mutated file: " << file->getName().str() << "\n";
                        }
                    }
                }
            } else {
                // not an actual file
            }
        }
    }
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

class MutatingVisitor : public clang::RecursiveASTVisitor<MutatingVisitor> {
private:
    clang::ASTContext *astContext;
    clang::PrintingPolicy pp;
    clang::SourceManager *SourceManager;
    
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
                newExprStr << "(MUTANT_NR == " << mutant_count++ <<" ? " << lhs << " " << clang::BinaryOperator::getOpcodeStr(elem).str() << " " << rhs << ": ";
                endBrackets += ")";
            }
        }
        
        // insert mutant before orig expression
        rewriter.InsertText(binOp->getLocStart(), newExprStr.str());
        // insert brackets to close mutant schemata's if statement
        rewriter.InsertTextAfterToken(binOp->getLocEnd(), endBrackets);
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
                    return VisitedSourcePaths.find(fE->tryGetRealPathName()) == VisitedSourcePaths.end();
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
                        case clang::BO_Add:
                            insertMutantSchemata(binOp, {clang::BO_Sub});
                            break;
                        case clang::BO_Sub:
                            insertMutantSchemata(binOp, {clang::BO_Add});
                            break;
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
private:
public:
    virtual std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &CI, StringRef file) {
        if (processingFile != getCurrentInput().getFile()) {
            written = false;
            processingFile = getCurrentInput().getFile();
        }
        
        // TODO: find out why this is being called multiple times per sourceFile we provide
        // it's visiting all stmt's 6 times... there is a huge speedup to be gained
        llvm::errs() << "Starting to mutate the following file and all of it's includes: " << file << "\n";
        rewriter = clang::Rewriter();
        rewriter.setSourceMgr(CI.getSourceManager(), CI.getLangOpts());
        return std::unique_ptr<clang::ASTConsumer> (new MutationConsumer(&CI)); // pass CI pointer to ASTConsumer
    }
    
    virtual void EndSourceFileAction() {
        // another ugly hack to prevent sehmentation faults
        if (!written) {
            // use false, as inPlace causes a sementation fault in clang's sourcemaneger calling the ComputeLineNumbers function
            writeChangedFiles(false);
            written = true;
        } else {
            // llvm::errs() << "Already written files for: " << getCurrentInput().getFile() << "\n";
        }
    }
};


// Apply a custom category to all command-line options so that they are the only ones displayed.
static llvm::cl::OptionCategory MutantShemataCategory("mutation-schemata options");


/**
 * Expecting: argv: -p ../googletest/build filePathToMutate1 filePathToMutate2 ...
 */
void setupClang(int argc, const char **argv) {
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
    
//    return result;
}

#endif // MS_CLANG_REWRITE


