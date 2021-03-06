/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import java.io {
    File,
    InputStream,
    FileInputStream,
    FilenameFilter
}
import java.util {
    Arrays
}

alias LocalResourceVirtualFileAlias => ResourceVirtualFile<Nothing,File, File, File>;
alias LocalFolderVirtualFileAlias => FolderVirtualFile<Nothing,File, File, File>;
alias LocalFileVirtualFileAlias => FileVirtualFile<Nothing,File, File, File>;

String normalizeSeparators(String path) 
        => if ('\\' == File.separatorChar)
            then path.replace("\\", "/")
            else path;


shared interface FileSystemVirtualFile satisfies WithParentVirtualFile{
    shared formal File file;

    shared actual default String name 
        => file.name;

    shared actual default String path
        => normalizeSeparators(file.path);
    
    shared actual default FolderVirtualFile<Nothing,File,File,File>? parent 
        => if (exists nativeParent = file.parentFile)
            then LocalFolderVirtualFile(nativeParent)
            else null;

    shared actual default Boolean \iexists() => file.\iexists();
}    
    
shared class LocalFileVirtualFile(file)
            satisfies FileVirtualFile<Nothing,File, File, File> & 
                       FileSystemVirtualFile {
    shared actual File file;
    
    name => (super of FileSystemVirtualFile).name;
    
    path => (super of FileSystemVirtualFile).path;
    
    shared actual FolderVirtualFile<Nothing, File, File, File>  parent {
        assert(exists theParent = (super of FileSystemVirtualFile).parent);
        return theParent;
    }

    shared actual InputStream inputStream {
        return FileInputStream( file );
    }

    equals(Object that) => (super of FileVirtualFile<Nothing,File,File,File>).equals(that);
    
    hash => (super of FileVirtualFile<Nothing,File,File,File>).hash;

    charset => null;

    nativeResource => file;
    
    shared actual Boolean \iexists() => (super of FileSystemVirtualFile).\iexists();
    
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing ceylonProject => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeProject => nothing;
}

shared class LocalFolderVirtualFile(file) 
            satisfies FolderVirtualFile<Nothing,File, File, File> &
                       FileSystemVirtualFile {
    shared actual File file;
    
    name => (super of FileSystemVirtualFile).name;
    
    path => (super of FileSystemVirtualFile).path;
    
    parent => (super of FileSystemVirtualFile).parent;
    
    
    children => Arrays.asList(
            if (exists folderChildren = file.listFiles())
            for (f in folderChildren)
            if (f.directory)
            then LocalFolderVirtualFile(f)
            else LocalFileVirtualFile(f));

    equals(Object that) => (super of FolderVirtualFile<Nothing,File,File,File>).equals(that);
    
    hash => (super of FolderVirtualFile<Nothing,File,File,File>).hash;
    
    shared actual LocalFileVirtualFile? findFile(String fileName) {
        value result
                = file.listFiles(object satisfies FilenameFilter {
                    accept(File dir, String name) => name == fileName;
                })[0];
        return
            if (exists result, !result.directory)
            then LocalFileVirtualFile(result)
            else null;
    }
    
    nativeResource => file;
    
    shared actual String[] toPackageName(BaseFolderVirtualFile srcDir) {
        if (is LocalFolderVirtualFile srcDir) {
            value fileAbsolutePath = file.absolutePath;
            value sourceDirAbsolutePath = srcDir.nativeResource.absolutePath;
            
            if (fileAbsolutePath.startsWith(sourceDirAbsolutePath)) {
                value relativePath = fileAbsolutePath.replaceFirst(sourceDirAbsolutePath, "");
                return normalizeSeparators(relativePath).split('/'.equals).sequence();
            }
        }
        return [];
    }

    shared actual Boolean \iexists() => (super of FileSystemVirtualFile).\iexists();

    suppressWarnings("expressionTypeNothing")
    shared actual Nothing ceylonProject => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing ceylonPackage => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing isSource => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing rootFolder => nothing;
    suppressWarnings("expressionTypeNothing")
    shared actual Nothing nativeProject => nothing;
}
