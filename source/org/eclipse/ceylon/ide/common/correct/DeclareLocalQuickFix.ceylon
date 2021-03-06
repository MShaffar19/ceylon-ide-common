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
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}

shared object declareLocalQuickFix {
    
    shared void enableLinkedMode(QuickFixData data, Tree.Term term) {
        
        if (exists type = term.typeModel) {
            value lm = platformServices.createLinkedMode(data.document);
            value proposals = typeCompletion.getTypeProposals {
                rootNode = data.rootNode;
                offset = data.node.startIndex.intValue();
                length = 5;
                infType = type;
                kind = "value";
            };
            lm.addEditableRegion(data.node.startIndex.intValue(), 5, 0, proposals);
            lm.install(this, -1, -1);
        }
    }
    
    shared void addDeclareLocalProposal(QuickFixData data) {
        value node = data.node;
        value st = nodes.findStatement(data.rootNode, node);
        
        if (is Tree.SpecifierStatement sst = st) {
            value se = sst.specifierExpression;
            value bme = sst.baseMemberExpression;
            if (bme == node,
                is Tree.BaseMemberExpression bme,
                exists e = se.expression,
                exists term = e.term) {
                
                value change
                        = platformServices.document
                            .createTextChange("Declare Local Value", data.phasedUnit);
                change.initMultiEdit();
                change.addEdit(InsertEdit(node.startIndex.intValue(), "value "));

                data.addQuickFix {
                    description = "Declare local value '``bme.identifier.text``'";
                    void change() {
                        change.apply();
                        enableLinkedMode(data, term);
                    }
                };
            }
        }
    }
}
