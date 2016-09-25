import com.redhat.ceylon.compiler.java.codegen {
    CodegenUtil
}
import com.redhat.ceylon.model.loader {
    NamingBase
}
import com.redhat.ceylon.model.loader.mirror {
    MethodMirror,
    TypeParameterMirror,
    VariableMirror
}
import com.redhat.ceylon.model.typechecker.model {
    Value,
    Declaration,
    Type,
    FunctionOrValue
}

import java.lang {
    JString=String
}
import java.util {
    ArrayList,
    Collections
}

shared class JObjectMirror(shared actual Value decl) extends AbstractClassMirror(decl) {
    abstract => false;
    
    ceylonToplevelAttribute => false;
    
    ceylonToplevelMethod => false;
    
    ceylonToplevelObject => true;
    
    satisfiedTypes => decl.type.satisfiedTypes;
    
    supertype => decl.type.extendedType;
    
    name => super.name + "_";
    
    scanExtraMembers(ArrayList<MethodMirror> methods)
            => methods.add(GetMethod(this));
}

shared class GetMethod(JObjectMirror obj) satisfies MethodMirror {
    shared Declaration declaration => obj.decl;

    abstract => false;
    
    constructor => false;
    
    declaredVoid => false;
    
    default => false;
    
    defaultAccess => false;
    
    enclosingClass => obj;
    
    final => true;
    
    getAnnotation(String? string) => null;
    
    annotationNames => Collections.emptySet<JString>();

    name => NamingBase.Unfix.get_.string;
    
    parameters
            => Collections.emptyList<VariableMirror>();
    
    protected => false;
    
    public => true;
    
    returnType => ceylonToJavaMapper.mapType(obj.decl.type);
    
    static => true;
    
    staticInit => false;
    
    typeParameters
            => Collections.emptyList<TypeParameterMirror>();
    
    variadic => false;
    
    defaultMethod => false;
}

shared String getJavaQualifiedName(Declaration decl)
        => let (fqn = CodegenUtil.getJavaNameOfDeclaration(decl))
        if (decl is FunctionOrValue && decl.toplevel,
            exists loc = fqn.lastOccurrence('.'))
        then fqn.initial(loc) //strip off the static method/getter name
        else fqn;
