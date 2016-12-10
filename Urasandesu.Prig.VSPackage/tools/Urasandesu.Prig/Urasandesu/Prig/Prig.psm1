﻿# 
# File: Prig.psm1
# 
# Author: Akira Sugiura (urasandesu@gmail.com)
# 
# 
# Copyright (c) 2012 Akira Sugiura
#  
#  This software is MIT License.
#  
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#



$here = Split-Path $MyInvocation.MyCommand.Path





New-Variable AssemblyNameExTypeName 'Urasandesu.Prig.AssemblyNameEx' -Option ReadOnly
New-Variable EnableProfilingKey 'COR_ENABLE_PROFILING' -Option ReadOnly
New-Variable EnableProfilingValueDisabled '0' -Option ReadOnly
New-Variable EnableProfilingValueEnabled '1' -Option ReadOnly
New-Variable ProfilerKey 'COR_PROFILER' -Option ReadOnly
New-Variable ProfilerValue '{532C1F05-F8F3-4FBA-8724-699A31756ABD}' -Option ReadOnly
New-Variable ProfilerCurrentDirectoryKey 'URASANDESU_PRIG_CURRENT_DIRECTORY' -Option ReadOnly
New-Variable ProfilerTargetProcessNameKey 'URASANDESU_PRIG_TARGET_PROCESS_NAME' -Option ReadOnly
New-Variable ProfilerTargetProcessNameValue '' -Option ReadOnly
New-Variable ProfilerTargetProcessArgumentKey 'URASANDESU_PRIG_TARGET_PROCESS_ARGUMENT' -Option ReadOnly
New-Variable ProfilerTargetProcessArgumentValue '(vstest\.executionengine)|(te\.processhost\.managed[^/]+/role=testexecution)' -Option ReadOnly



function ConcatIfNonEmpty {
    param (
        [string]
        $String1,
         
        [string]
        $String2
    )

    if (![string]::IsNullOrEmpty($String1) -and ![string]::IsNullOrEmpty($String2)) {
        $String1 + $String2
    }
}



function ToRootNamespace {
    param (
        [System.Reflection.Assembly]
        $AssemblyInfo
    )

    $AssemblyInfo.GetName().Name + '.Prig'
}



function ToSignAssembly {
    param (
        [System.Reflection.Assembly]
        $AssemblyInfo, 

        [string]
        $KeyFile
    )
    
    if ($AssemblyInfo.GetName().GetPublicKeyToken().Length -eq 0) {
        $false
    } else {
        if ([string]::IsNullOrEmpty($KeyFile)) {
            $false
        } else {
            $true
        }
    }
}



function ToProcessorArchitectureConstant {
    param (
        [System.Reflection.Assembly]
        $AssemblyInfo
    )

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "_M_IX86" }
        'Amd64'     { "_M_AMD64" }
        'MSIL'      { "_M_MSIL" }
        Default     { "_M_MSIL" }
    }
}



function ToTargetFrameworkVersionConstant {
    param (
        [string]
        $TargetFrameworkVersion
    )
    
    switch ($TargetFrameworkVersion)
    {
        'v3.5'      { "_NET_3_5" }
        'v4.0'      { "_NET_4" }
        'v4.5'      { "_NET_4_5" }
        'v4.5.1'    { "_NET_4_5_1" }
        Default     { "_NET_4" }
    }
}



function ToDefineConstants {
    param (
        [System.Reflection.Assembly]
        $AssemblyInfo, 

        [string]
        $TargetFrameworkVersion
    )
    
    $result = (ToProcessorArchitectureConstant $AssemblyInfo), (ToTargetFrameworkVersionConstant $TargetFrameworkVersion)
    $result -join ';'
}



function ToPlatformTarget {
    param (
        [System.Reflection.Assembly]
        $AssemblyInfo
    )

    switch ($AssemblyInfo.GetName().ProcessorArchitecture)
    {
        'X86'       { "x86" }
        'Amd64'     { "x64" }
        'MSIL'      { "AnyCPU" }
        Default     { "AnyCPU" }
    }
}



function ToReferenceInclude {
    param (
        [System.Reflection.Assembly[]]
        $ReferencedAssemblyInfos
    )
    
    foreach ($refAsmInfo in $ReferencedAssemblyInfos) {
        @"
        <Reference Include="$($refAsmInfo.GetName().Name)">
            <HintPath>$($refAsmInfo.Location)</HintPath>
        </Reference>
"@
    }
}



function StripGenericParameterCount {
    param (
        [string]
        $Name
    )

    $Name -replace '`\d+', ''
}



function ConvertTypeToFullName {
    param (
        [type]
        $Type, 

        [System.Collections.ArrayList]
        $List
    )
    
    $defName = $Type.FullName
    if ($defName -eq $null) {
        $defName = $Type.Name
    } else {
        $defName = "global::" + $defName
    }
        
    if ($Type.IsGenericParameter -and !$Type.IsNested) {
        $defName = $Type.Name
    } elseif ($Type.IsGenericParameter) {
        $defName = ([string]$defName).Replace("+",".")
    } elseif (!$Type.IsGenericParameter -and $Type.IsNested) {
        $defName = (ConvertTypeToFullName $Type.DeclaringType) + '.' + $Type.Name
    } elseif ($Type.IsGenericType -and !$Type.IsGenericTypeDefinition) {
        $defName = "global::" + $Type.Namespace + "." + $Type.Name
    } elseif ($Type.HasElementType -and $Type.IsArray) {
        if ($null -eq $List) {
            $List = New-Object System.Collections.ArrayList
        }
        [void]$List.Add(("[{0}]" -f (New-Object string ',', ($Type.GetArrayRank() - 1))))
        $defName = (ConvertTypeToFullName $Type.GetElementType() $List)
    } elseif ($Type.HasElementType) {
        $defName = ConvertTypeToFullName $Type.GetElementType()
    }

    if ($Type.IsGenericType) {
        if ($Type.HasElementType -and $Type.IsGenericTypeDefinition) {
            $defName = $Type.Name
        }
        $genericArgs = $Type.GetGenericArguments()
        if ($Type.Name -match '`(\d+)') {
            $genericArgs = $genericArgs[($genericArgs.Length - ([int]$Matches[1]))..($genericArgs.Length - 1)]
            $defName = StripGenericParameterCount $defName
            $genericArgNames = @()
            foreach ($genericArg in $genericArgs) {
                $genericArgNames += (ConvertTypeToFullName $genericArg)
            }
            $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
        }
    }

    if (0 -lt $List.Count) {
        $defName += ($List -join '')
        $List.Clear()
    }
    $defName
}
New-Variable ValueTypeFullName (ConvertTypeToFullName ([System.ValueType])) -Option ReadOnly



function ConvertTypeToClassName {
    param (
        [type]
        $Type
    )
    
    if (!$Type.IsGenericParameter -and $Type.IsNested) {
        $defName = (ConvertTypeToStubName $Type.DeclaringType) + $Type.Name
    } else {
        $defName = $Type.Name
    }

    if ($Type.IsGenericType) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $genericArgNames += (ConvertTypeToFullName $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}



function ConvertTypeToBaseName {
    param (
        [type]
        $Type
    )
    
    if (!$Type.IsGenericParameter -and $Type.IsNested) {
        $defName = (ConvertTypeToStubName $Type.DeclaringType) + $Type.Name
    } else {
        $defName = $Type.Name
    }

    if ($Type.IsGenericType) {
        $defName = StripGenericParameterCount $defName
    }
    $defName + "Base"
}



function ConvertStubToClassName {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )
    
    $defName = $Stub.Alias
    if ($Stub.Target.IsGenericMethod) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            $genericArgNames += (ConvertTypeToFullName $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}



function ConvertMethodBaseToClassName {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )
    
    $defName = ConvertToIndirectionStubName $MethodBase
    if ($MethodBase.IsGenericMethod) {
        $defName = StripGenericParameterCount $defName
        $genericArgNames = @()
        foreach ($genericArg in $MethodBase.GetGenericArguments()) {
            $genericArgNames += (ConvertTypeToFullName $genericArg)
        }
        $defName = ($defName + "<" + ($genericArgNames -join ', ') + ">")
    }
    $defName
}



function ConvertMethodBaseToLambdaParameters {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    if (IsMethodBaseSignaturePublic $MethodBase) {
        ConvertPublicMethodBaseToLambdaParameters $MethodBase
    } else {
        ConvertNonPublicMethodBaseToLambdaParameters $MethodBase
    }
}


function GetParametersForLambda {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    if (!$MethodBase.IsStatic) {
        if ($MethodBase.DeclaringType.IsClass) {
            $type = $MethodBase.DeclaringType
        } else {
            $type = $MethodBase.DeclaringType.MakeByRefType()
        }
        $attr = [System.Reflection.ParameterAttributes]::None
        $name = '@this'
        New-Object psobject | 
            Add-Member NoteProperty Type $type -PassThru | 
            Add-Member NoteProperty Attribute $attr -PassThru | 
            Add-Member NoteProperty Name $name -PassThru
    }

    $paramInfos = $MethodBase.GetParameters()
    foreach ($paramInfo in $paramInfos) {
        $type = $paramInfo.ParameterType
        $attr = $paramInfo.Attributes
        $name = $paramInfo.Name
        New-Object psobject | 
            Add-Member NoteProperty Type $type -PassThru | 
            Add-Member NoteProperty Attribute $attr -PassThru | 
            Add-Member NoteProperty Name $name -PassThru
    }
}



function ConvertPublicMethodBaseToLambdaParameters {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    $params = @(GetParametersForLambda $MethodBase)

    if ($params.Length -eq 0) {
        '()'
    } elseif (@($params | ? { $_.Type.IsByRef }).Length -eq 0) {
        if ($params.Length -eq 1) {
            $params[0].Name
        } else {
            '({0})' -f (($params | % { $_.Name }) -join ', ')
        }
    } else {
        $paramStrs = New-Object System.Collections.Generic.List[string]
        foreach ($param in $params) {
            $strs = New-Object System.Collections.Generic.List[string]
            if ($param.Type.IsByRef) {
                if (($param.Attribute -band [System.Reflection.ParameterAttributes]::Out) -ne 0) {
                    $strs.Add('out')
                } else {
                    $strs.Add('ref')
                }
            }
            $strs.Add((ConvertTypeToFullName $param.Type))
            $strs.Add($param.Name)
            $paramStrs.Add(($strs -join ' '))
        }
        '({0})' -f ($paramStrs -join ', ')
    }
}



function ConvertNonPublicMethodBaseToLambdaParameters {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    'args'
}



function ConvertMethodBaseToLambdaParameterRemarks {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    if (IsMethodBaseSignaturePublic $MethodBase) {
        ConvertPublicMethodBaseToLambdaParameterRemarks $MethodBase
    } else {
        ConvertNonPublicMethodBaseToLambdaParameterRemarks $MethodBase
    }
}



function ConvertPublicMethodBaseToLambdaParameterRemarks {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    [string]::Empty
}



function ConvertNonPublicMethodBaseToLambdaParameterRemarks {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    $params = @(GetParametersForLambda $MethodBase)

    if ($params.Length -eq 0) {
        '// args.Length == 0: because this method has no parameters.'
    } else {
        $paramStrs = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $params.Length; $i++) { 
            $param = $params[$i]
            $strs = New-Object System.Collections.Generic.List[string]
            $strs.Add(('args[{0}]:' -f $i))
            if ($param.Type.IsByRef) {
                if (($param.Attribute -band [System.Reflection.ParameterAttributes]::Out) -ne 0) {
                    $strs.Add('out')
                } else {
                    $strs.Add('ref')
                }
            }
            $strs.Add((ConvertTypeToFullName $param.Type))
            $strs.Add($param.Name)
            $paramStrs.Add(($strs -join ' '))
        }
        '// {0}' -f ($paramStrs -join ', ')
    }
}



function IsPublic {
    param (
        [type]
        $Type
    )
    
    $targetType = $Type
    if ($Type.HasElementType) { 
        $targetType = $Type.GetElementType()
    }
    $targetType.IsPublic -or $targetType.IsNestedPublic
}



function IsSignaturePublic {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )

    IsMethodBaseSignaturePublic $Stub.Target
}



function IsMethodBaseSignaturePublic {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    $result = $true
    
    if (!$MethodBase.IsStatic) {
        $result = $result -and (IsPublic $MethodBase.DeclaringType)
    }

    $paramInfos = $MethodBase.GetParameters()
    $result = $result -and !(0 -lt @($paramInfos | ? { !(IsPublic $_.ParameterType) }).Length)

    switch ($MethodBase) {
        { $_ -is [System.Reflection.MethodInfo] } {
            [System.Reflection.MethodInfo]$methodInfo = $null
            $methodInfo = $MethodBase
            $result = $result -and (IsPublic $methodInfo.ReturnType)
            break
        }
        { $_ -is [System.Reflection.ConstructorInfo] } {
            # nop
            break
        }
        Default {
            throw New-Object System.ArgumentException ('Parameter $MethodBase({0}) is not supported.' -f $MethodBase.GetType()) 
        }
    }
    $result
}



function ExistsIndirectionDelegate {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )

    $null -ne $Stub.IndirectionDelegate
}



function GetImplementedInterface {
    param (
        [System.Reflection.MethodInfo]
        $MethodInfo
    )

    $declaringType = $MethodInfo.DeclaringType
    foreach ($interface in $declaringType.GetInterfaces()) {
        $mapping = $declaringType.GetInterfaceMap($interface)

        if ($mapping.TargetType -ne $declaringType) { 
            continue 
        }

        $index = [array]::IndexOf($mapping.TargetMethods, $MethodInfo)
        if ($index -eq -1) { 
            continue 
        }

        if (!$MethodInfo.IsFinal -or !$MethodInfo.IsVirtual) {
            return $null
        }

        if ($mapping.InterfaceMethods[$index] -ne $null) {
            $interfaceMethod = $mapping.InterfaceMethods[$index]
            return New-Object psobject | 
                        Add-Member NoteProperty 'Interface' $interface -PassThru | 
                        Add-Member NoteProperty 'InterfaceMethod' $interfaceMethod -PassThru
        }
    }

    $null
}



function GetExplicitlyImplementedInterface {
    param (
        [System.Reflection.MethodInfo]
        $MethodInfo
    )

    $result = GetImplementedInterface $MethodInfo
    if ($null -ne $result) {
        $name = $result.InterfaceMethod.Name
        if (!$MethodInfo.Name.Equals($name, [System.StringComparison]::Ordinal)) {
            $result
        }
    }
}



function ConvertTypeToGenericParameterConstraintClause {
    param (
        [type]
        $GenericArgument
    )

    $names = New-Object 'System.Collections.Generic.List[string]'
    $gpa = $GenericArgument.GenericParameterAttributes
    [System.Reflection.GenericParameterAttributes]$constraints = 0
    $constraints = $gpa -band [System.Reflection.GenericParameterAttributes]::SpecialConstraintMask
    if (($constraints -band [System.Reflection.GenericParameterAttributes]::NotNullableValueTypeConstraint) -ne 0) {
        $names.Add('struct')
    }

    if (($constraints -band [System.Reflection.GenericParameterAttributes]::ReferenceTypeConstraint) -ne 0) {
        $names.Add('class')
    }

    $typeConstraints = $GenericArgument.GetGenericParameterConstraints()
    foreach ($typeConstraint in $typeConstraints) {
        $fullName = ConvertTypeToFullName $typeConstraint
        if ($fullName -ne $ValueTypeFullName) {
            $names.Add($fullName)
        }
    }

    if (($constraints -band [System.Reflection.GenericParameterAttributes]::DefaultConstructorConstraint) -ne 0 -and 
        ($constraints -band [System.Reflection.GenericParameterAttributes]::NotNullableValueTypeConstraint) -eq 0) {
        $names.Add('new()')
    }

    if ($names.Count -eq 0) {
        $null
    } else {
        "where $($GenericArgument.Name) : $($names -join ', ')"
    }
}



function ConvertTypeToGenericParameterConstraints {
    param (
        [type]
        $Type
    )

    $constraintClauses = New-Object 'System.Collections.Generic.List[string]'
    if ($Type.IsGenericType) {
        foreach ($genericArg in $Type.GetGenericArguments()) {
            $constraintClause = ConvertTypeToGenericParameterConstraintClause $genericArg
            if ($null -eq $constraintClause) { continue }

            $constraintClauses.Add($constraintClause)
        }
    }

    $constraintClauses -join ' '
}



function ConvertStubToGenericParameterConstraints {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )

    $constraintClauses = New-Object 'System.Collections.Generic.List[string]'
    if ($Stub.Target.IsGenericMethod) {
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            $constraintClause = ConvertTypeToGenericParameterConstraintClause $genericArg
            if ($null -eq $constraintClause) { continue }

            $constraintClauses.Add($constraintClause)
        }
    }

    $constraintClauses -join ' '
}



function ConvertTypeToStubName {
    param (
        [type]
        $Type
    )

    if ($Type.HasElementType) {
        $typeStubName = ConvertTypeToStubName $Type.GetElementType()
    } elseif (!$Type.IsGenericParameter -and $Type.IsNested) {
        $typeStubName = (ConvertTypeToStubName $Type.DeclaringType) + $Type.Name
    } else {
        $typeStubName = $Type.Name
    }

    if ($Type.IsByRef) {
        $typeStubName += "Ref"
    }

    if ($Type.IsArray) {
        if (1 -lt $Type.GetArrayRank()) {
            $typeStubName += $Type.GetArrayRank()
        } else {
            $typeStubName += "Array"
        }
    }

    if ($Type.IsPointer) {
        $typeStubName += "Ptr"
    }
    
    if ($Type.IsGenericType) {
        $genericArgs = $Type.GetGenericArguments()
        if ($Type.Name -match '`(\d+)') {
            $typeStubName = $typeStubName -replace '`\d+', ''
            $typeStubName += ConvertGenericArgumentsToStubName $genericArgs[($genericArgs.Length - ([int]$Matches[1]))..($genericArgs.Length - 1)]
        }
    }
    
    $typeStubName
}



function ConvertParameterInfoToStubName {
    param (
        [System.Reflection.ParameterInfo]
        $ParameterInfo
    )

    ConvertTypeToStubName $ParameterInfo.ParameterType
}



function ConvertGenericArgumentToStubName {
    param (
        [type]
        $GenericArgument
    )

    "Of" + (ConvertTypeToStubName $GenericArgument)
}



function ConvertParameterInfosToStubName {
    param (
        [System.Reflection.ParameterInfo[]]
        $ParameterInfos
    )

    $paramsStubName = ""
    if (0 -lt $ParameterInfos.Length) {
        $paramStubNames = New-Object "System.Collections.Generic.List[string]"
        foreach ($param in $ParameterInfos) {
            $paramStubNames.Add((ConvertParameterInfoToStubName $param))
        }
        $paramsStubName = [string]::Join('', $paramStubNames)
    }
    $paramsStubName
}



function ConvertGenericArgumentsToStubName {
    param (
        [type[]]
        $GenericArguments
    )

    $genericArgsStubName = ""
    if (0 -lt $GenericArguments.Length) {
        $genericArgStubNames = New-Object "System.Collections.Generic.List[string]"
        foreach ($genericArg in $GenericArguments) {
            $genericArgStubNames.Add((ConvertGenericArgumentToStubName $genericArg))
        }
        $genericArgsStubName = [string]::Join('', $genericArgStubNames)
    }
    $genericArgsStubName
}



function ConvertConstructorInfoToStubName {
    param (
        [System.Reflection.ConstructorInfo]
        $ConstructorInfo
    )

    $stubName = $(if ($ConstructorInfo.IsStatic) { "StaticConstructor" } else { "Constructor" })
    $paramsStubName = ConvertParameterInfosToStubName $ConstructorInfo.GetParameters() 
    $stubName + $paramsStubName
}



function ConvertMethodInfoToStubName {
    param (
        [System.Reflection.MethodInfo]
        $MethodInfo
    )

    $stubName = $MethodInfo.Name
    $stubName = $stubName -creplace '^get_(.*)', '$1Get'
    $stubName = $stubName -creplace '^set_(.*)', '$1Set'
    if ($stubName -cmatch '^op_Explicit(.*)' -or $stubName -cmatch '^op_Implicit(.*)') {
        $returnStubName = ConvertTypeToStubName $MethodInfo.ReturnType
    }
    $stubName = $stubName -creplace '^op_(.*)', '$1Op'
    $stubName = $stubName -creplace '^add_(.*)', 'Add$1'
    $stubName = $stubName -creplace '^remove_(.*)', 'Remove$1'
    if ($MethodInfo.IsGenericMethod) {
        $genericArgsStubName = ConvertGenericArgumentsToStubName $MethodInfo.GetGenericArguments()
    }

    $paramsStubName = ConvertParameterInfosToStubName $MethodInfo.GetParameters()

    $stubName + $genericArgsStubName + $(if ([string]::IsNullOrEmpty($returnStubName)) { $paramsStubName } else { $returnStubName })
}



function ConvertToIndirectionStubName {
    param (
        [System.Reflection.MethodBase]
        $MethodBase
    )

    switch ($MethodBase) {
        { $_ -is [System.Reflection.ConstructorInfo] } {  
            ConvertConstructorInfoToStubName $MethodBase
        }
        { $_ -is [System.Reflection.MethodInfo] } {  
            $result = GetExplicitlyImplementedInterface $MethodBase
            if ($null -eq $result) {
                ConvertMethodInfoToStubName $MethodBase
            } else {
                ($result.Interface.Namespace -replace '\.', '') + 
                    (ConvertTypeToStubName $result.Interface) + 
                    (ConvertMethodInfoToStubName $result.InterfaceMethod)
            }
        }
    }
}



function ConvertTypeToGenericParameterArray {
    param (
        [type]
        $Type
    )

    $typeofParams = New-Object 'System.Collections.Generic.List[string]'
    if ($Type.IsGenericType) {
        foreach ($genericArg in $Type.GetGenericArguments()) {
            if ($genericArg.IsGenericParameter) {
                $typeofParams.Add(("typeof({0})" -f $genericArg.Name))
            } else {
                $typeofParams.Add('null')
            }
        }
    }

    "new Type[] {{ {0} }}" -f ($typeofParams -join ', ')
}



function ConvertStubToGenericParameterArray {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )

    $typeofParams = New-Object 'System.Collections.Generic.List[string]'
    if ($Stub.Target.IsGenericMethod) {
        foreach ($genericArg in $Stub.Target.GetGenericArguments()) {
            if ($genericArg.IsGenericParameter) {
                $typeofParams.Add(("typeof({0})" -f $genericArg.Name))
            } else {
                $typeofParams.Add('null')
            }
        }
    }

    "new Type[] {{ {0} }}" -f ($typeofParams -join ', ')
}



function ConvertStubToStubsXml {
    param (
        [Urasandesu.Prig.Framework.PilotStubberConfiguration.IndirectionStub]
        $Stub
    )

    @"
@"<?xml version=""1.0"" encoding=""utf-8""?>
<stubs>
  <add name=""{0}"" alias=""{1}"">
    {2}
  </add>
</stubs>"
"@ -f $Stub.Name, $Stub.Alias, ($Stub.Xml -replace '"', '""')
}



. $(Join-Path $here Prig.Add-PrigAssembly.ps1)
. $(Join-Path $here Prig.Remove-PrigAssembly.ps1)
. $(Join-Path $here Prig.ConvertTo-PrigAssemblyName.ps1)
. $(Join-Path $here Prig.ConvertTo-ProcessorArchitectureString.ps1)
. $(Join-Path $here Prig.Disable-PrigTestAdapter.ps1)
. $(Join-Path $here Prig.Enable-PrigTestAdapter.ps1)
. $(Join-Path $here Prig.Find-IndirectionTarget.ps1)
. $(Join-Path $here Prig.Get-AssemblyNameExs.ps1)
. $(Join-Path $here Prig.Get-AssemblyNameExsFrom.ps1)
. $(Join-Path $here Prig.Get-IndirectionStubSetting.ps1)
. $(Join-Path $here Prig.Get-PackageName.ps1)
. $(Join-Path $here Prig.Get-PackageToolsPath.ps1)
. $(Join-Path $here Prig.New-PrigCsproj.ps1)
. $(Join-Path $here Prig.New-PrigProxiesCs.ps1)
. $(Join-Path $here Prig.New-PrigProxyTypeIntroducersCs.ps1)
. $(Join-Path $here Prig.New-PrigStubsCs.ps1)
. $(Join-Path $here Prig.New-PrigTypeIntroducersCs.ps1)
. $(Join-Path $here Prig.New-PrigTokensCs.ps1)
. $(Join-Path $here Prig.Start-PrigSetup.ps1)





Export-ModuleMember -Function *-* -Alias *
