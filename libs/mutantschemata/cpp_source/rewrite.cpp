//------------------------------------------------------------------------------
// Mutant schemata using Clang rewriter and RecursiveASTVisitor
//
// Sten Vercammem (sten.vercammen@uantwerpen.be)
//------------------------------------------------------------------------------

#include <cstdio>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <initializer_list>

#include "clang/Analysis/CFG.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/AST/ASTContext.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/Basic/Diagnostic.h"
#include "clang/Basic/FileManager.h"
#include "clang/Basic/SourceManager.h"
#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/TargetOptions.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/TextDiagnosticPrinter.h"
#include "clang/Lex/HeaderSearch.h"
#include "clang/Lex/Preprocessor.h"
#include "clang/Parse/ParseAST.h"
#include "clang/Rewrite/Core/Rewriter.h"
#include "clang/Rewrite/Core/RewriteBuffer.h"
#include "clang/Rewrite/Frontend/Rewriters.h"
#include "llvm/Support/Host.h"
#include "llvm/Support/raw_ostream.h"


#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/Host.h"
#include "llvm/Support/Casting.h"

#include "clang/Basic/DiagnosticOptions.h"
#include "clang/Frontend/TextDiagnosticPrinter.h"

#include "clang/Basic/LangOptions.h"
#include "clang/Basic/FileSystemOptions.h"

#include "clang/Basic/SourceManager.h"
#include "clang/Lex/HeaderSearch.h"
#include "clang/Basic/FileManager.h"

#include "clang/Frontend/Utils.h"

#include "clang/Basic/TargetOptions.h"
#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/Version.h"

#include "clang/Lex/Preprocessor.h"
#include "clang/Lex/PreprocessorOptions.h"
#include "clang/Frontend/FrontendOptions.h"

#include "clang/Basic/IdentifierTable.h"
#include "clang/Basic/Builtins.h"

#include "clang/AST/ASTContext.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/AST/RecursiveASTVisitor.h"
#include "clang/Sema/Sema.h"
#include "clang/AST/DeclBase.h"
#include "clang/AST/Type.h"
#include "clang/AST/Decl.h"
#include "clang/Sema/Lookup.h"
#include "clang/Sema/Ownership.h"
#include "clang/AST/DeclGroup.h"

#include "clang/Parse/Parser.h"

#include "clang/Parse/ParseAST.h"
#include "clang/Frontend/CompilerInstance.h"

#include "clang/Rewrite/Core/Rewriter.h"
#include "clang/Rewrite/Frontend/Rewriters.h"

using namespace clang;

int mutant_count = 1;

bool negateBinaryOperators = true;
bool negateOverloadedOperators = false;
bool negateUnaryOperators = false;

// By implementing RecursiveASTVisitor, we can specify which AST nodes
// we're interested in by overriding relevant methods.
class MyASTVisitor : public RecursiveASTVisitor<MyASTVisitor> {
private:
    Rewriter &TheRewriter;
    PrintingPolicy pp;
    
    void mutate_schemata(BinaryOperator *binOp, std::initializer_list<BinaryOperatorKind> list) {
        
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
                newExprStr << "(MUTANT_NR == " << mutant_count++ <<" ? " << lhs << " " << BinaryOperator::getOpcodeStr(elem).str() << " " << rhs << ": ";
                endBrackets += ")";
            }
        }
        // insert mutant before orig expression
        TheRewriter.InsertText(binOp->getLocStart(), newExprStr.str());
        // insert brackets to close mutant schemata's if statement
        TheRewriter.InsertTextAfterToken(binOp->getLocEnd(), endBrackets);
    }
    
    
    
public:
    MyASTVisitor(Rewriter &R, LangOptions &lo) : TheRewriter(R), pp(lo) {}
    
    bool VisitStmt(Stmt *s) {
        // mutate all expressions
        if (isa<Expr>(s)) {
            if (isa<BinaryOperator>(s)) {
                BinaryOperator *binOp = cast<BinaryOperator>(s);
                if (negateBinaryOperators) {
                    switch (binOp->getOpcode()) {
                            // Multiplicative operators
                        case BO_Mul:
                            mutate_schemata(binOp, {BO_Div});
                            break;
                        case BO_Div:
                            mutate_schemata(binOp, {BO_Mul});
                            break;
                        case BO_Rem:
                            //TODO
                            break;
                            // Additive operators
                        case BO_Add:
                            mutate_schemata(binOp, {BO_Sub});
                            break;
                        case BO_Sub:
                            mutate_schemata(binOp, {BO_Add});
                            break;
                            // Bitwise shift operators
                        case BO_Shl:
                            mutate_schemata(binOp, {BO_Shr});
                            break;
                        case BO_Shr:
                            mutate_schemata(binOp, {BO_Shl});
                            break;
                            // Three-way comparison operator
                            //case BO_Cmp:
                            //TODO
                            //    break;
                            // Relational operators
                        case BO_LT:
                            mutate_schemata(binOp, {BO_GT});
                            break;
                        case BO_GT:
                            mutate_schemata(binOp, {BO_LT});
                            break;
                        case BO_LE:
                            mutate_schemata(binOp, {BO_GE});
                            break;
                        case BO_GE:
                            mutate_schemata(binOp, {BO_LE});
                            break;
                            // Equality operators
                        case BO_EQ:
                            mutate_schemata(binOp, {BO_NE});
                            break;
                        case BO_NE:
                            mutate_schemata(binOp, {BO_EQ});
                            break;
                            // Bitwise AND operator
                        case BO_And:
                            mutate_schemata(binOp, {BO_Or});
                            break;
                        case BO_Xor:
                            //TODO
                            break;
                        case BO_Or:
                            mutate_schemata(binOp, {BO_And});
                            break;
                            // Logical AND operator
                        case BO_LAnd:
                            mutate_schemata(binOp, {BO_LOr});
                            break;
                        case BO_LOr:
                            mutate_schemata(binOp, {BO_LAnd});
                            break;
                            // Assignment operators
                        case BO_Assign:
                            //TODO
                            break;
                        case BO_MulAssign:
                            mutate_schemata(binOp, {BO_DivAssign});
                            break;
                        case BO_DivAssign:
                            mutate_schemata(binOp, {BO_MulAssign});
                            break;
                        case BO_RemAssign:
                            //TODO
                            break;
                        case BO_AddAssign:
                            mutate_schemata(binOp, {BO_SubAssign});
                            break;
                        case BO_SubAssign:
                            mutate_schemata(binOp, {BO_AddAssign});
                            break;
                        case BO_ShlAssign:
                            mutate_schemata(binOp, {BO_ShrAssign});
                            break;
                        case BO_ShrAssign:
                            mutate_schemata(binOp, {BO_ShlAssign});
                            break;
                        case BO_AndAssign:
                            mutate_schemata(binOp, {BO_OrAssign});
                            break;
                        case BO_XorAssign:
                            //TODO
                            break;
                        case BO_OrAssign:
                            mutate_schemata(binOp, {BO_AndAssign});
                            break;
                        default:
                            break;
                    }
                } else if (negateUnaryOperators) {
                    //TODO
                } else if (false) {
                    if (binOp->isPtrMemOp()) {
                        
                        
                    } else if (binOp->isMultiplicativeOp()) {   // BO_Mul, BO_Div, BO_Rem
                        mutate_schemata(binOp, {BO_Mul, BO_Div, BO_Rem});
                    } else if (binOp->isAdditiveOp()) {         // BO_Add, BO_Sub
                        mutate_schemata(binOp, {BO_Add, BO_Sub});
                    } else if (binOp->isShiftOp()) {            // BO_Shl, BO_Shr
                        mutate_schemata(binOp, {BO_Shl, BO_Shr});
                    } else if (binOp->isBitwiseOp()) {          // BO_And, BO_Xor, BO_Or
                        mutate_schemata(binOp, {BO_And, BO_Xor, BO_Or});
                    } else if (binOp->isRelationalOp()) {       // BO_LT, BO_GT, BO_LE, BO_GE
                        mutate_schemata(binOp, {BO_LT, BO_GT, BO_LE, BO_GE});
                    } else if (binOp->isEqualityOp()) {         // BO_EQ, BO_NE
                        mutate_schemata(binOp, {BO_EQ, BO_NE});
                    } else if (binOp->isComparisonOp()) {       // BO_Cmp, isEqualityOp, isRelationalOp
                        mutate_schemata(binOp, {BO_EQ, BO_LT, BO_GT, BO_LE, BO_GE, BO_NE});
                    } else if (binOp->isLogicalOp()) {          // BO_LAnd, BO_LOr
                        mutate_schemata(binOp, {BO_LAnd, BO_LOr});
                    } else if (binOp->isAssignmentOp()) {       // BO_Assign, BO_MulAssign, BO_DivAssign, BO_RemAssign, BO_AddAssign, BO_SubAssign, BO_ShlAssign, BO_ShrAssign, BO_AndAssign, BO_XorAssign, BO_OrAssign
                        mutate_schemata(binOp, {BO_Assign, BO_MulAssign, BO_DivAssign, BO_RemAssign, BO_AddAssign, BO_SubAssign, BO_ShlAssign, BO_ShrAssign, BO_AndAssign, BO_XorAssign, BO_OrAssign});
                    } else if (binOp->isCompoundAssignmentOp()) {   // BO_MulAssign, BO_DivAssign, BO_RemAssign, BO_AddAssign, BO_SubAssign, BO_ShlAssign, BO_ShrAssign, BO_AndAssign, BO_XorAssign, BO_OrAssign
                        mutate_schemata(binOp, {BO_MulAssign, BO_DivAssign, BO_RemAssign, BO_AddAssign, BO_SubAssign, BO_ShlAssign, BO_ShrAssign, BO_AndAssign, BO_XorAssign, BO_OrAssign});
                    } else if (binOp->isShiftAssignOp()) {      // BO_ShlAssign, BO_ShrAssign
                        mutate_schemata(binOp, {BO_ShlAssign, BO_ShrAssign});
                    }
                }
            } else if (isa<CXXOperatorCallExpr>(s)) {
                if (negateOverloadedOperators) {
                    CXXOperatorCallExpr *oExpr = cast<CXXOperatorCallExpr>(s);
                    
                    OverloadedOperatorKind oOp = oExpr->getOperator();
                    if (oOp == OO_Plus) {
                        printf("found CXXOperatorCallExpr expr of Addition in %s\n", oExpr->getStmtClassName());
                        //TODO check if this is really the place where the oOp is declared
                        FunctionDecl *dDecl = oExpr->getDirectCallee();
                        if (dDecl == nullptr) {
                            llvm::errs() << "Overloaded operator is not a functionDecl -> paradox";
                            exit(-1);
                        }
                        FunctionDecl *def = dDecl->getDefinition();
                        if (def == nullptr) {
                            printf("definition is nullptr???\n");
                            exit(1);
                        }
                        def->dump();
                        if (!def->isOverloadedOperator()) {
                            printf("overloaded operator is not an overloaded operator -> paradox");
                            exit(1);
                        }
                        DeclContext *dCtx = def->getParent();
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
                                FunctionDecl *funcDecl = (*it)->getAsFunction();
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
                                //                            Stmt *func = (*it)->getBody();
                                //                            if (func) {
                                //                                printf("exists\n");
                                //                                func->dump();
                                //                                func
                                //                                if (isa<CXXOperatorCallExpr>(func)) {
                                //                                    CXXOperatorCallExpr *oExprOther = cast<CXXOperatorCallExpr>(func);
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

// Implementation of the ASTConsumer interface for reading an AST produced
// by the Clang parser.
class MyASTConsumer : public ASTConsumer {
private:
    MyASTVisitor Visitor;
    
public:
    MyASTConsumer(Rewriter &R, LangOptions &lo) : Visitor(R, lo) {}
    
    // Override the method that gets called for each parsed top-level
    // declaration.
    virtual bool HandleTopLevelDecl(DeclGroupRef DR) {
        for (DeclGroupRef::iterator b = DR.begin(), e = DR.end(); b != e; ++b)
            // Traverse the declaration using our AST visitor.
            Visitor.TraverseDecl(*b);
        return true;
    }
};



void setupClang(char* allFiles, char* includeDir, char* workingDir) {
    // CompilerInstance will hold the instance of the Clang compiler for us,
    // managing the various objects needed to run the compiler.
    
    std::string buf;                // Have a buffer string
    std::stringstream ss(allFiles); // Insert the string into a stream
    
    std::vector<std::string> tokens; // Create vector to hold our words
    while(getline(ss, buf, ',')) {
        tokens.push_back(buf);
    }
    
    for (std::string file: tokens) {
        std::unique_ptr<CompilerInstance> TheCompInst(new CompilerInstance());
        TheCompInst->createDiagnostics();
        
        
        LangOptions &lo = TheCompInst->getLangOpts();
        lo.CPlusPlus = 1;
        
        // Initialize target info with the default triple for our platform.
        auto TO = std::make_shared<TargetOptions>();
        TO->Triple = llvm::sys::getDefaultTargetTriple();
        TargetInfo *TI =
        TargetInfo::CreateTargetInfo(TheCompInst->getDiagnostics(), TO);
        TheCompInst->setTarget(TI);
        
        TheCompInst->createFileManager();
        FileManager &FileMgr = TheCompInst->getFileManager();
        TheCompInst->createSourceManager(FileMgr);
        SourceManager &SourceMgr = TheCompInst->getSourceManager();
        
        // -- WORK IN PROGRESS ---
        // Header searcher
        std::shared_ptr<HeaderSearchOptions> hso = TheCompInst->getHeaderSearchOptsPtr();
        hso->AddPath(includeDir, frontend::Quoted, false, false);
        HeaderSearch hs(hso, SourceMgr, TheCompInst->getDiagnostics(), lo, TI);
        // this doe not seem to set everything correctly
        std::vector<DirectoryLookup> lookups;
        for (auto entry : hso->UserEntries) {
            printf("path := %s\n", entry.Path.c_str());
            auto lookup = DirectoryLookup(FileMgr.getDirectory(entry.Path), SrcMgr::CharacteristicKind::C_System, false);
            if (!lookup.getDir()) {
                printf("Clang could not interpret path %s\n", entry.Path.c_str());
                //throw //SpecificError<ClangCouldNotInterpretPath>(a, where, "Clang could not interpret path " + entry.Path);
            }
            lookups.push_back(lookup);
        }
        hs.SetSearchPaths(lookups, 0, 0, true);
        
        // set working directory
        printf("WorkingDir:= %s\n", TheCompInst->getFileSystemOpts().WorkingDir.c_str());
        TheCompInst->getFileSystemOpts().WorkingDir = workingDir;

        // -----------------------

        
        
        TheCompInst->createPreprocessor(TU_Module);
        TheCompInst->createASTContext();
        
        // A Rewriter helps us manage the code rewriting task.
        Rewriter TheRewriter;
        TheRewriter.setSourceMgr(SourceMgr, TheCompInst->getLangOpts());
        
        printf("file: %s\n", file.c_str());
        // Set the main file handled by the source manager to the input file.
        const FileEntry *FileIn = FileMgr.getFile(file);
        SourceMgr.setMainFileID(
                                SourceMgr.createFileID(FileIn, SourceLocation(), SrcMgr::C_User));
        TheCompInst->getDiagnosticClient().BeginSourceFile(
                                                           TheCompInst->getLangOpts(), &TheCompInst->getPreprocessor());
        
        // Create an AST consumer instance which is going to get called by
        // ParseAST.
        MyASTConsumer TheConsumer(TheRewriter, lo);
        // Parse the file to AST, registering our consumer as the AST consumer.
        ParseAST(TheCompInst->getPreprocessor(), &TheConsumer,
                 TheCompInst->getASTContext());
        // At this point the rewriter's buffer should be full with the rewritten
        // file contents.
        //const RewriteBuffer *RewriteBuf =
        //TheRewriter.getRewriteBufferFor(SourceMgr.getMainFileID());
        //TheRewriter.overwriteChangedFiles();
        
        bool AllWritten = true;
        for (std::map<FileID, RewriteBuffer>::iterator I = TheRewriter.buffer_begin(), E = TheRewriter.buffer_end(); I != E; ++I) {
            printf("you know:\n");
            const char *include = "extern int MUTANT_NR;\n";
            int i = 0;
            bool alreadyIncluded = true;
            for (RewriteBuffer::iterator it = I->second.begin(), end = I->second.end(); it != end; ++it) {
                printf("%c", *it);
                if (*it == '\n') {
                    break;
                }
                if (include[i++] != *it) {
                    alreadyIncluded = false;
                    break;
                }
            }
            printf("I do now, and %i\n", alreadyIncluded);
            if (!alreadyIncluded) {
                printf("including it\n");
                I->second.InsertTextAfter(0, include);
            }
            TheRewriter.overwriteChangedFiles();
            printf("WorkingDir:= %s\n", TheCompInst->getFileSystemOpts().WorkingDir.c_str());

            
            //            printf("filename: %s\n", SourceMgr.getFileEntryForID(I->first)->getName());
            
            //            const FileEntry *Entry = SourceMgr.getFileEntryForID(I->first);
            //            Entry->getName
            //            AtomicallyMovedFile File(SourceMgr.getDiagnostics(), Entry->getName(), AllWritten);
            //            if (File.ok()) {
            //                I->second.write(File.getStream());
            //            }
        }
        //        printf("done\n");
        
    }
    
    
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        llvm::errs() << "Usage: rewritersample <file,otherfile,...> includeDir workingDir\n";
        return 1;
    }
    
    setupClang(argv[1], argv[2], argv[3]);
    
    return mutant_count;
}
