/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.completion {
    getRefinementTextFor,
    overloads,
    completionManager
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    platformServices
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    TypeParameter,
    Declaration,
    ModelUtil,
    TypeDeclaration,
    NothingType
}

import java.util {
    LinkedHashMap,
    ArrayList,
    HashSet
}

shared class ObjectClassDefinitionGenerator(
    brokenName, node, rootNode, image, returnType, parameters, document)
        extends DefinitionGenerator() {
    
    shared actual String brokenName;
    shared actual Tree.MemberOrTypeExpression node;
    shared actual Tree.CompilationUnit rootNode;
    shared actual Icons image;
    shared actual Type? returnType;
    shared actual LinkedHashMap<String,Type>? parameters;
    CommonDocument document;
    
    isFormalSupported => classGenerator;
    
    Boolean isUpperCase => brokenName.first?.uppercase else false;
    
    shared actual String description {
        if (exists parameters) {
            value params = StringBuilder();
            appendParameters(parameters, params, defaultedSupertype);
            value supertype = supertypeDeclaration(returnType) else "";
            return "'class ``brokenName + params.string + supertype``'";
        } else {
            return "'object ``brokenName``'";
        }
    }
    
    shared actual String generateInternal(String indent, 
        String delim, Boolean isFormal) {
        value def = StringBuilder();
        value isVoid = !(returnType exists);
        if (classGenerator) {
            value typeParams = ArrayList<TypeParameter>();
            value typeParamDef = StringBuilder();
            value typeParamConstDef = StringBuilder();
            appendTypeParams2(typeParams, 
                typeParamDef, typeParamConstDef, 
                returnType);
            if (exists parameters) {
                appendTypeParams3(typeParams, 
                    typeParamDef, typeParamConstDef, 
                    parameters.values());
            }
            if (typeParamDef.size > 0) {
                typeParamDef.insert(0, "<");
                typeParamDef.deleteTerminal(1);
                typeParamDef.append(">");
            }
            value defIndent = platformServices.document.defaultIndent;
            value supertype 
                    = if (isVoid) then null
                    else supertypeDeclaration(returnType);
            def.append("class ")
                .append(brokenName)
                .append(typeParamDef.string);
            assert (exists parameters);
            appendParameters(parameters, def, 
                defaultedSupertype);
            if (exists supertype) {
                def.append(delim)
                   .append(indent)
                   .append(defIndent)
                   .append(defIndent)
                   .append(supertype);
            }
            def.append(typeParamConstDef.string);
            def.append(" {").append(delim);
            if (!isVoid) {
                appendMembers(indent, delim, def, defIndent);
            }
            def.append(indent).append("}");
        } else if (objectGenerator) {
            value defIndent = platformServices.document.defaultIndent;
            value supertype = 
                    if (isVoid) then null 
                    else supertypeDeclaration(returnType);
            def.append("object ")
               .append(brokenName);
            if (exists supertype) {
                def.append(delim)
                    .append(indent)
                    .append(defIndent)
                    .append(defIndent)
                    .append(supertype);
            }
            def.append(" {").append(delim);
            if (!isVoid) {
                appendMembers(indent, delim, def, defIndent);
            }
            def.append(indent).append("}");
        } else {
            return "<error!>";
        }
        return def.string;
    }
    
    Boolean classGenerator => isUpperCase && parameters exists;
    
    Boolean objectGenerator => !isUpperCase && !parameters exists;
    
    shared actual void generateImports(CommonImportProposals importProposals) {
        importProposals.importType {
            type = returnType;
        };
        if (exists parameters) {
            importProposals.importTypes { *parameters.values() };
        }
        if (exists returnType) {
            importMembers(importProposals);
        }
    }
    
    void importMembers(CommonImportProposals importProposals) {
        //TODO: this is a major copy/paste from appendMembers() below
        value td = defaultedSupertype;
        value ambiguousNames = HashSet<String>();
        value unit = rootNode.unit;
        value members = td.getMatchingMemberDeclarations(unit, null, "", 0, null).values();
        for (dwp in members) {
            value dec = dwp.declaration;
            for (d in overloads(dec)) {
                if (d.formal /*&& td.isInheritedFromSupertype(d)*/) {
                    importProposals.importSignatureTypes {
                        declaration = d;
                    };
                    ambiguousNames.add(d.name);
                }
            }
        }
        if (!td is NothingType) {
            for (superType in td.supertypeDeclarations) {
                for (m in superType.members) {
                    if (m.shared) {
                        Declaration? r = td.getMember(m.name, null, false);
                        if (!(r?.refines(m) else false),
                            // !r.getContainer().equals(ut) &&  
                            !ambiguousNames.add(m.name)) {
                            importProposals.importSignatureTypes {
                                declaration = m;
                            };
                        }
                    }
                }
            }
        }
    }
    
    void appendMembers(String indent, String delim, StringBuilder def, String defIndent) {
        value td = defaultedSupertype;
        value ambiguousNames = HashSet<String>();
        value unit = rootNode.unit;
        value members = 
                td.getMatchingMemberDeclarations(unit, null, "", 0, null)
                    .values();
        for (dwp in members) {
            value dec = dwp.declaration;
            if (ambiguousNames.add(dec.name)) {
                for (d in overloads(dec)) {
                    if (d.formal /*&& td.isInheritedFromSupertype(d)*/) {
                        appendRefinementText {
                            indent = indent;
                            delim = delim;
                            def = def;
                            defIndent = defIndent;
                            d = d;
                        };
                    }
                }
            }
        }
        for (superType in td.supertypeDeclarations) {
            for (m in superType.members) {
                if (m.shared) {
                    Declaration? r = td.getMember(m.name, null, false);
                    if (!(r?.refines(m) else false),
                        // !r.getContainer().equals(ut)) && 
                        ambiguousNames.add(m.name)) {
                        appendRefinementText {
                            indent = indent;
                            delim = delim;
                            def = def;
                            defIndent = defIndent;
                            d = m;
                        };
                    }
                }
            }
        }
    }
    
    TypeDeclaration defaultedSupertype {
        if (isNotBasic(returnType), exists returnType) {
            return returnType.declaration;
        } else {
            value unit = rootNode.unit;
            return ModelUtil.intersectionType(returnType, unit.basicType, unit).declaration;
        }
    }
    
    void appendRefinementText(String indent, String delim, StringBuilder def, String defIndent, Declaration d) {
        assert (exists returnType);
        value text = getRefinementTextFor {
            d = d;
            pr = completionManager.getRefinedProducedReference(returnType, d);
            unit = node.unit;
            isInterface = false;
            ci = null;
            indent = "";
            containsNewline = false;
            preamble = true;
            addParameterTypesInCompletions = false;
        };
        String realText;
        if (exists parameters,
            parameters.containsKey(d.name),
            exists loc = text.firstInclusion(" =>")) {
            realText = text[0:loc] + ";";
        }
        else {
            realText = text;
        }
        def.append(indent)
            .append(defIndent)
            .append(realText)
            .append(delim);
    }
    
    Boolean isNotBasic(Type? returnType) {
        if (ModelUtil.isTypeUnknown(returnType)) {
            return false;
        } else if (exists returnType) {
            value rtd = returnType.declaration;
            value bd = rtd.unit.basicDeclaration;
            if (returnType.\iclass) {
                return rtd.inherits(bd);
            } else if (returnType.\iinterface) {
                return false;
            } else if (returnType.intersection) {
                for (st in returnType.satisfiedTypes) {
                    if (st.\iclass) {
                        return rtd.inherits(bd);
                    }
                }
                return false;
            }
        }
        return false;
    }
}

String? supertypeDeclaration(Type? returnType) {
    if (ModelUtil.isTypeUnknown(returnType)) {
        return null;
    } else if (exists returnType) {
        if (returnType.\iclass) {
            return " extends ``returnType.asString()``()"; //TODO: supertype arguments!
        } else if (returnType.\iinterface) {
            return " satisfies ``returnType.asString()``";
        } else if (returnType.intersection) {
            value extendsClause = StringBuilder();
            value satisfiesClause = StringBuilder();
            for (st in returnType.satisfiedTypes) {
                if (st.\iclass) {
                    extendsClause.append(" extends ``st.asString()``()"); //TODO: supertype arguments!
                } else if (st.\iinterface) {
                    if (satisfiesClause.empty) {
                        satisfiesClause.append(" satisfies ");
                    } else {
                        satisfiesClause.append(" & ");
                    }
                    satisfiesClause.append(st.asString());
                }
            }
            return extendsClause.string + satisfiesClause.string;
        }
    }
    return null;
}

Boolean isValidSupertype(Type? returnType) {
    if (ModelUtil.isTypeUnknown(returnType)) {
        return true;
    } else if (exists returnType) {
        if (exists r = returnType.caseTypes) {
            return false;
        }
        value rtd = returnType.declaration;
        if (returnType.\iclass) {
            return !rtd.final;
        } else if (returnType.\iinterface) {
            value cd = rtd.unit.callableDeclaration;
            return rtd != cd;
        } else if (returnType.intersection) {
            for (st in returnType.satisfiedTypes) {
                if (!isValidSupertype(st)) {
                    return false;
                }
            }
            return true;
        }
    }
    return false;
}

ObjectClassDefinitionGenerator? createObjectClassDefinitionGenerator(
    brokenName, node, rootNode, document) {
    
    String brokenName;
    Tree.MemberOrTypeExpression node;
    Tree.CompilationUnit rootNode;
    CommonDocument document;
    
    value isUpperCase = brokenName.first?.uppercase else false;
    value fav = FindArgumentsVisitor(node);
    rootNode.visit(fav);
    value unit = node.unit;
    value paramTypes = getParameters(fav);
    Type? returnType;
    if (exists type = unit.denotableType(fav.expectedType)) {
        if (type.\iobject || type.anything) {
            returnType = null;
        }
        else if (unit.isOptionalType(type)) {
            returnType = type.eliminateNull();
        }
        else {
            returnType = type;
        }
    }
    else {
        returnType = null;
    }
    if (!isValidSupertype(returnType)) {
        return null;
    }
    return 
    if (exists paramTypes, isUpperCase)
        then ObjectClassDefinitionGenerator {
            brokenName = brokenName;
            node = node;
            rootNode = rootNode;
            image = Icons.localClass;
            returnType = returnType;
            parameters = paramTypes;
            document = document;
        }
    else if (!exists paramTypes, !isUpperCase)
        then ObjectClassDefinitionGenerator {
            brokenName = brokenName;
            node = node;
            rootNode = rootNode;
            image = Icons.localAttribute;
            returnType = returnType;
            parameters = null;
            document = document;
        }
    else null;
}
