import ceylon.collection {
    HashSet,
    unlinked,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    FindImportNodeVisitor
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    CommonDocument,
    TextChange,
    TextEdit,
    DeleteEdit,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Function,
    FunctionOrValue,
    Module {
        \iLANGUAGE_MODULE_NAME=languageModuleName
    },
    ParameterList,
    Type,
    TypeDeclaration,
    TypedDeclaration
}

import java.lang {
    JIterable=Iterable,
    JString=String
}
import java.util {
    JHashSet=HashSet,
    JIterator=Iterator,
    JList=List,
    JMap=Map,
    JSet=Set,
    Collections
}
import com.redhat.ceylon.ide.common.doc {
    Icons
}

shared object importProposals {
    
    shared void addImportProposals(QuickFixData data) {
        if (is Tree.BaseMemberOrTypeExpression|Tree.SimpleType node = data.node,
            exists id = nodes.getIdentifyingNode(node)) {
            
            value rootNode = data.rootNode;
            value brokenName = id.text;
            value mod = rootNode.unit.\ipackage.\imodule;
            
            for (dec in findImportCandidates(mod, brokenName, rootNode)) {
                createImportProposal(data, dec);
            }
        }
    }

    Set<Declaration> findImportCandidates(Module mod, String name, Tree.CompilationUnit rootNode)
            => HashSet {
                stability = unlinked;
                elements
                        = CeylonIterable(mod.allVisiblePackages)
                            .filter((pkg) => !pkg.nameAsString.empty)
                            .map((pkg) => let (Declaration? d = pkg.getMember(name, null, false)) d)
                            .coalesced;
            };
    
    void createImportProposal(QuickFixData data, Declaration declaration) {
        value change = platformServices.document.createTextChange("Add Import", data.phasedUnit);
        change.initMultiEdit();
        
        value edits = importEdits {
            rootNode = data.rootNode;
            declarations = Collections.singleton(declaration);
            aliases = null;
            declarationBeingDeleted = null;
            doc = change.document;
        };
        
        for (e in edits) {
            change.addEdit(e);
        }
        String proposedName = declaration.name;
        /*String brokenName = id.getText();
         if (!brokenName.equals(proposedName)) {
            change.addEdit(new ReplaceEdit(id.getStartIndex(), brokenName.length(),
                    proposedName));
         }*/
        String pname = declaration.unit.\ipackage.nameAsString;
        String description =
            "Add import of '``proposedName``' in package '``pname``'";
        
        data.addQuickFix(description, change, null, false, Icons.imports);
    }
    
    shared List<InsertEdit> importEdits(
        Tree.CompilationUnit rootNode,
        JIterable<Declaration> declarations,
        JIterable<JString>? aliases,
        Declaration? declarationBeingDeleted,
        CommonDocument doc) {
        String delim = doc.defaultLineDelimiter;
        
        value edits = ArrayList<InsertEdit>();
        value packages = CeylonIterable(declarations)
                .map((decl) => decl.unit.\ipackage)
                .distinct;

        for (p in packages) {
            StringBuilder text = StringBuilder();
            if (!exists aliases) {
                for (d in declarations) {
                    if (d.unit.\ipackage == p) {
                        text.appendCharacter(',').append(delim)
                            .append(platformServices.document.defaultIndent)
                            .append(escaping.escapeName(d));
                    }
                }
            } else {
                JIterator<JString> aliasIter = aliases.iterator();
                for (d in declarations) {
                    String? theAlias = aliasIter.next()?.string;
                    if (d.unit.\ipackage == p) {
                        text.append(",").append(delim).append(platformServices.document.defaultIndent);
                        if (exists theAlias, theAlias != d.name) {
                            text.append(theAlias).appendCharacter('=');
                        }
                        text.append(escaping.escapeName(d));
                    }
                }
            }
            
            if (exists importNode = findImportNode(rootNode, p.nameAsString)) {
                Tree.ImportMemberOrTypeList imtl = importNode.importMemberOrTypeList;
                if (imtl.importWildcard exists) {
                    // Do Nothing
                } else {
                    Integer insertPosition = getBestImportMemberInsertPosition(importNode);
                    if (exists declarationBeingDeleted,
                        imtl.importMemberOrTypes.size() == 1,
                        imtl.importMemberOrTypes.get(0).declarationModel == declarationBeingDeleted) {
                        text.delete(0, 2);
                    }
                    edits.add(InsertEdit(insertPosition, text.string));
                }
            } else {
                Integer insertPosition = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0, "import " + escaping.escapePackageName(p)
                            + " {" + delim).append(delim + "}");
                if (insertPosition == 0) {
                    text.append(delim);
                } else {
                    text.insert(0, delim);
                }
                edits.add(InsertEdit(insertPosition, text.string));
            }
        }
        
        return edits;
    }
    
    shared List<TextEdit> importEditForMove(
        Tree.CompilationUnit rootNode,
        JIterable<Declaration> declarations,
        JIterable<JString>? aliases,
        String newPackageName,
        String oldPackageName,
        CommonDocument doc) {
        
        value delim = doc.defaultLineDelimiter;
        value result = ArrayList<TextEdit>();
        value set = HashSet<Declaration>();
        for (d in declarations) {
            set.add(d);
        }
        StringBuilder text = StringBuilder();
        if (!exists aliases) {
            for (d in declarations) {
                text.append(",").append(delim).append(platformServices.document.defaultIndent).append(d.name);
            }
        } else {
            JIterator<JString> aliasIter = aliases.iterator();
            for (d in declarations) {
                String? \ialias = aliasIter.next()?.string;
                text.append(",").append(delim).append(platformServices.document.defaultIndent);
                if (exists \ialias, \ialias != d.name) {
                    text.append(\ialias).appendCharacter('=');
                }
                text.append(d.name);
            }
        }
        if (exists oldImportNode = findImportNode(rootNode, oldPackageName),
            exists imtl = oldImportNode.importMemberOrTypeList) {
            variable value remaining = 0;
            for (imt in imtl.importMemberOrTypes) {
                if (!imt.declarationModel in set) {
                    remaining++;
                }
            }
            if (remaining == 0) {
                assert (exists startIndex = oldImportNode.startIndex);
                assert (exists endIndex = oldImportNode.endIndex);
                value start = startIndex.intValue();
                value end = endIndex.intValue();
                result.add(DeleteEdit(start, end - start));
            } else {
                assert (exists startIndex = imtl.startIndex);
                assert (exists endIndex = imtl.endIndex);
                value start = startIndex.intValue();
                value end = endIndex.intValue();
                String formattedImport = formatImportMembers(delim, platformServices.document.defaultIndent, set, imtl);
                result.add(ReplaceEdit(start, end - start, formattedImport));
            }
        }
        value pack = rootNode.unit.\ipackage;
        if (pack.qualifiedNameString != newPackageName) {
            if (exists importNode = findImportNode(rootNode, newPackageName)) {
                Tree.ImportMemberOrTypeList imtl = importNode.importMemberOrTypeList;
                if (imtl.importWildcard exists) {
                    // Do Nothing
                } else {
                    Integer insertPosition = getBestImportMemberInsertPosition(importNode);
                    result.add(InsertEdit(insertPosition, text.string));
                }
            } else {
                Integer insertPosition = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0, "import " + newPackageName + " {" + delim).append(delim + "}");
                if (insertPosition == 0) {
                    text.append(delim);
                } else {
                    text.insert(0, delim);
                }
                result.add(InsertEdit(insertPosition, text.string));
            }
        }
        return result;
    }
    shared String formatImportMembers(String delim, String indent, Set<Declaration> set, Tree.ImportMemberOrTypeList imtl) {
        StringBuilder sb = StringBuilder().append("{").append(delim);
        for (imt in imtl.importMemberOrTypes) {
            if (exists dec = imt.declarationModel, !dec in set) {
                sb.append(indent);
                if (exists theAlias = imt.\ialias) {
                    String aliasText = theAlias.identifier.text;
                    sb.append(aliasText).appendCharacter('=');
                }
                value id = imt.identifier.text;
                sb.append(id).appendCharacter(',').append(delim);
            }
        }
        
        // The following line replace the previous Java version with
        // a Java StringBuilder :
        //
        //     sb.setLength(sb.length() - 1 - delim.length());
        sb.deleteTerminal(1 + delim.size);
        sb.append(delim).appendCharacter('}');
        return sb.string;
    }
    
    shared Integer getBestImportInsertPosition(Tree.CompilationUnit cu) {
        if (exists endIndex = cu.importList.endIndex) {
            return endIndex.intValue();
        } else {
            return 0;
        }
    }
    
    shared Tree.Import? findImportNode(Tree.CompilationUnit cu, String packageName) {
        value visitor = FindImportNodeVisitor(packageName);
        cu.visit(visitor);
        return visitor.result;
    }
    
    shared Integer getBestImportMemberInsertPosition(Tree.Import importNode) {
        value imtl = importNode.importMemberOrTypeList;
        if (exists wildcard = imtl.importWildcard) {
            assert (exists startIndex = wildcard.startIndex);
            return startIndex.intValue();
        } else {
            value imts = imtl.importMemberOrTypes;
            if (imts.empty) {
                assert (exists startIndex = imtl.startIndex);
                return startIndex.intValue() + 1;
            } else if (exists endIndex = imts.get(imts.size() - 1).endIndex) {
                return endIndex.intValue();
            } else {
                return imtl.endIndex.intValue();
            }
        }
    }
    
    shared Integer applyImportsInternal(TextChange change, JIterable<Declaration> declarations, JIterable<JString>? aliases, Tree.CompilationUnit cu, CommonDocument doc, Declaration? declarationBeingDeleted) {
        variable Integer il = 0;
        for (ie in importEdits(cu, declarations, aliases, declarationBeingDeleted, doc)) {
            il += ie.text.size;
            change.addEdit(ie);
        }
        return il;
    }
    
    shared Integer applyImports(TextChange change, JSet<Declaration> declarations, Tree.CompilationUnit rootNode, CommonDocument doc, Declaration? declarationBeingDeleted = null)
            => applyImportsInternal(change, declarations, null, rootNode, doc, declarationBeingDeleted);
    
    shared Integer applyImportsWithAliases(TextChange change, JMap<Declaration,JString> declarations, Tree.CompilationUnit cu, CommonDocument doc, Declaration? declarationBeingDeleted = null)
            => applyImportsInternal(change, declarations.keySet(), declarations.values(), cu, doc, declarationBeingDeleted);
    
    shared void importSignatureTypes(Declaration declaration, Tree.CompilationUnit rootNode, JSet<Declaration> declarations) {
        if (is TypedDeclaration declaration) {
            TypedDeclaration td = declaration;
            importType(declarations, td.type, rootNode);
        }
        if (is Functional declaration) {
            Functional fun = declaration;
            for (pl in fun.parameterLists) {
                for (p in pl.parameters) {
                    importSignatureTypes(p.model, rootNode, declarations);
                }
            }
        }
    }
    
    shared void importTypes(JSet<Declaration> declarations, JIterable<Type>? types, Tree.CompilationUnit rootNode) {
        if (exists types) {
            for (type in types) {
                importType(declarations, type, rootNode);
            }
        }
    }
    shared void importType(JSet<Declaration> declarations, Type? type, Tree.CompilationUnit rootNode) {
        if (exists type) {
            if (type.unknown || type.nothing) {
                // Do Nothing
            } else if (type.union) {
                for (t in type.caseTypes) {
                    importType(declarations, t, rootNode);
                }
            } else if (type.intersection) {
                for (t in type.satisfiedTypes) {
                    importType(declarations, t, rootNode);
                }
            } else {
                importType(declarations, type.qualifyingType, rootNode);
                TypeDeclaration td = type.declaration;
                if (type.classOrInterface && td.toplevel) {
                    importDeclaration(declarations, td, rootNode);
                    for (arg in type.typeArgumentList) {
                        importType(declarations, arg, rootNode);
                    }
                }
            }
        }
    }
    
    shared void importDeclaration(JSet<Declaration> declarations, Declaration declaration, Tree.CompilationUnit rootNode) {
        if (!declaration.parameter) {
            value p = declaration.unit.\ipackage;
            value pack = rootNode.unit.\ipackage;
            if (!p.nameAsString.empty
                        && p!=pack
                        && p.nameAsString!=\iLANGUAGE_MODULE_NAME
                        && (!declaration.classOrInterfaceMember || declaration.staticallyImportable)) {
                if (!isImported(declaration, rootNode)) {
                    declarations.add(declaration);
                }
            }
        }
    }
    
    shared Boolean isImported(Declaration declaration, Tree.CompilationUnit rootNode) {
        for (i in rootNode.unit.imports) {
            if (exists abstraction = nodes.getAbstraction(declaration), i.declaration == abstraction) {
                return true;
            }
        }
        return false;
    }
    
    shared void importCallableParameterParamTypes(Declaration declaration, JHashSet<Declaration> decs, Tree.CompilationUnit cu) {
        if (is Functional declaration) {
            Functional fun = declaration;
            JList<ParameterList> pls = fun.parameterLists;
            if (!pls.empty) {
                for (p in pls.get(0).parameters) {
                    FunctionOrValue pm = p.model;
                    importParameterTypes(pm, cu, decs);
                }
            }
        }
    }
    
    shared void importParameterTypes(Declaration dec, Tree.CompilationUnit cu, JHashSet<Declaration> decs) {
        if (is Function dec) {
            for (ppl in dec.parameterLists) {
                for (pp in ppl.parameters) {
                    importSignatureTypes(pp.model, cu, decs);
                }
            }
        }
    }
}
