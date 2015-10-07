import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.completion {
    overloads,
    getRefinementTextFor
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Unit
}

import java.lang {
    Character
}
import java.util {
    HashSet
}

shared interface RefineFormalMembersQuickFix<IFile, Document, InsertEdit, TextEdit, TextChange, Region, Project, Data, ICompletionResult>
        satisfies AbstractQuickFix<IFile, Document, InsertEdit, TextEdit, TextChange, Region, Project, ICompletionResult> 
                & DocumentChanges<Document,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit
        given Data satisfies QuickFixData<Project> {
    
    shared formal Character getDocChar(Document doc, Integer offset);
    
    shared formal void newRefineFormalMembersProposal(Data data, String desc);
    
    shared void addRefineFormalMembersProposal(Data data, Boolean ambiguousError) {
        value node = data.node;
        if (node is Tree.ClassBody
            || node is Tree.InterfaceBody
                || node is Tree.ClassDefinition
                || node is Tree.InterfaceDefinition
                || node is Tree.ObjectDefinition
                || node is Tree.ObjectExpression) {
            
            if (is ClassOrInterface ci = node.scope, exists cin = ci.name) {
                String name = if (ci.name.startsWith("anonymous#"))
                              then "anonymous class"
                              else "'" + ci.name + "'";
                
                String desc = if (ambiguousError)
                              then "Refine inherited ambiguous and formal members of " + name
                              else "Refine inherited formal members of " + name;
                
                newRefineFormalMembersProposal(data, desc);
            }
        }
    }
    
    shared TextChange? refineFormalMembers(Data data, IFile file, Integer editorOffset) {
        value rootNode = data.rootNode;
        value node = data.node;
        value change = newTextChange("Refine Members", file);
        value document = getDocumentForChange(change);

        initMultiEditChange(change);
        
        //TODO: copy/pasted from CeylonQuickFixAssistant
        Tree.Body body;
        variable Integer offset;
        if (is Tree.ClassDefinition node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.InterfaceDefinition node) {
            body = (node).interfaceBody;
            offset = -1;
        } else if (is Tree.ObjectDefinition node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.ObjectExpression node) {
            body = (node).classBody;
            offset = -1;
        } else if (is Tree.ClassBody|Tree.InterfaceBody node) {
            body = node;
            offset = editorOffset;
        } else {
            //TODO: run a visitor to find the containing body!
            return null; //TODO: popup error dialog
        }
        value isInterface = body is Tree.InterfaceBody;
        value statements = body.statements;
        String indent;
        value bodyIndent = indents.getIndent(node, document);
        value delim = indents.getDefaultLineDelimiter(document);
        if (statements.empty) {
            indent = delim + bodyIndent + indents.defaultIndent;
            if (offset < 0) {
                offset = body.startIndex.intValue() + 1;
            }
        } else {
            value statement = statements.get(statements.size() - 1);
            indent = delim + indents.getIndent(statement, document);
            if (offset < 0) {
                offset = statement.endIndex.intValue();
            }
        }
        
        value result = StringBuilder();
        value already = HashSet<Declaration>();
        assert (is ClassOrInterface ci = node.scope);
        value unit = node.unit;
        value ambiguousNames = HashSet<String>();

        //TODO: does not return unrefined overloaded  
        //      versions of a method with one overlaad
        //      already refined
        value proposals = completionManager.getProposals(node, ci, "", false, rootNode).values();
        
        for (dwp in CeylonIterable(proposals)) {
            value dec = dwp.declaration;
            for (d in overloads(dec)) {
                try {
                    if (d.formal, ci.isInheritedFromSupertype(d)) {
                        appendRefinementText(isInterface, indent, result, ci, unit, d);
                        importProposals.importSignatureTypes(d, rootNode, already);
                        ambiguousNames.add(d.name);
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        for (superType in CeylonIterable(ci.supertypeDeclarations)) {
            for (m in CeylonIterable(superType.members)) {
                try {
                    if (m.shared) {
                        Declaration? r = ci.getMember(m.name, null, false);
                        value foo = if (exists r) then !r.refines(m) && !r.container.equals(ci) else true;
                        
                        if (foo && ambiguousNames.add(m.name)) {
                            appendRefinementText(isInterface, indent, result, ci, unit, m);
                            importProposals.importSignatureTypes(m, rootNode, already);
                        }
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        
        if (getDocChar(document, offset) == '}', result.size > 0) {
            result.append(delim).append(bodyIndent);
        }
        
        importProposals.applyImports(change, already, rootNode, document);
        addEditToChange(change, newInsertEdit(offset, result.string));
        
        return change;
    }
    
    void appendRefinementText(Boolean isInterface, String indent, StringBuilder result,
        ClassOrInterface ci, Unit unit, Declaration member) {
        
        value pr = completionManager.getRefinedProducedReference(ci, member);
        value rtext = getRefinementTextFor(member, pr, unit, isInterface, ci, indent, true,
            true, indents, true);
        
        result.append(indent).append(rtext).append(indent);
    }
}
