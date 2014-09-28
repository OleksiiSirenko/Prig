﻿# 
# File: NuGet.New-PrigTokensCs.ps1
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



function New-PrigTokensCs {
    param ($WorkDirectory, $AssemblyInfo, $Section, $TargetFrameworkVersion)

    $content = @"
#if $(ToTargetFrameworkVersionConstant $TargetFrameworkVersion) && $(ToProcessorArchitectureConstant $AssemblyInfo)
//------------------------------------------------------------------------------ 
// <auto-generated> 
// This code was generated by a tool. 
// Assembly                 : $($AssemblyInfo.GetName().Name)
// Runtime Version          : $($AssemblyInfo.ImageRuntimeVersion)
// Assembly Version         : $($AssemblyInfo.GetName().Version.ToString())
// Processor Architecture   : $(ToProcessorArchitectureString $AssemblyInfo)
// 
// Changes to this file may cause incorrect behavior and will be lost if 
// the code is regenerated. 
// </auto-generated> 
//------------------------------------------------------------------------------


using Urasandesu.Prig.Framework;

"@ + $(foreach ($stub in $Section.Stubs) {
@"

[assembly: Indirectable($(ConcatIfNonEmpty $stub.Target.DeclaringType.Namespace '.')Prig.P$(ConvertTypeToBaseName $stub.Target.DeclaringType).TokenOf$($stub.Name))]
"@}) + @"
"@ + $(foreach ($namespaceGrouped in $Section.GroupedStubs) {
@"


namespace $(ConcatIfNonEmpty $namespaceGrouped.Key '.')Prig
{
"@ + $(foreach ($declTypeGrouped in $namespaceGrouped) {
@"

    public abstract class P$(ConvertTypeToBaseName $declTypeGrouped.Key)
    {
"@ + $(foreach ($stub in $declTypeGrouped) {
@"

        internal const int TokenOf$($stub.Name) = 0x$($stub.Target.MetadataToken.ToString('X8'));
"@}) + @"

    }
"@}) + @"

}
"@}) + @"

#endif
"@
    
    New-Object psobject | 
        Add-Member NoteProperty 'Path' ([System.IO.Path]::Combine($WorkDirectory, 'AutoGen\Tokens.g.cs')) -PassThru | 
        Add-Member NoteProperty 'Content' $content -PassThru
}
