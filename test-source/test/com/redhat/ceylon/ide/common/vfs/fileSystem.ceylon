import ceylon.file {
    Path
}
import ceylon.test {
    test
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    LocalFolderVirtualFile
}
import java.io {
    JFile=File
}

shared class LocalFileSystemTest() extends BaseTest<JFile,JFile,JFile>() {
    shared actual Path rootCeylonPath = resourcesRoot.childResource("local").path;
    
    shared actual FolderVirtualFile<JFile,JFile,JFile> rootVirtualFile =
            LocalFolderVirtualFile(JFile(rootCeylonPath.absolutePath.string));
    
    test
    shared void testLocalResources() => testResourceTree();
}