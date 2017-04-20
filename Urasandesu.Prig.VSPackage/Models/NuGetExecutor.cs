﻿/* 
 * File: NuGetExecutor.cs
 * 
 * Author: Akira Sugiura (urasandesu@gmail.com)
 * 
 * 
 * Copyright (c) 2015 Akira Sugiura
 *  
 *  This software is MIT License.
 *  
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *  
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */



using Microsoft.Practices.Unity;
using System.Linq;
using System.Text.RegularExpressions;
using Urasandesu.NAnonym.Mixins.System.IO;

namespace Urasandesu.Prig.VSPackage.Models
{
    class NuGetExecutor : ProcessExecutor, INuGetExecutor
    {
        [Dependency]
        public IEnvironmentRepository EnvironmentRepository { private get; set; }

        // NOTE: The last space of `OutputDirectory` parameter and `source` parameter is intended. 
        //       See also the following question: [msbuild - Illegal characters in path for nuget pack - Stack Overflow](http://stackoverflow.com/questions/17322147/illegal-characters-in-path-for-nuget-pack).

        public string StartPacking(string nuspec, string outputDirectory)
        {
            var nuget = EnvironmentRepository.GetNuGetPath();
            var args = string.Format("pack \"{0}\" -OutputDirectory \"{1} \"", nuspec, outputDirectory);
            return StartProcessWithoutShell(nuget, args, p => p.StandardOutput.ReadToEnd());
        }

        public string StartSourcing(string name, string source)
        {
            var nuget = EnvironmentRepository.GetNuGetPath();
            if (HaveAddedSources(name))
            {
                var args = string.Format("sources update -name \"{0}\" -source \"{1} \"", name, source);
                return StartProcessWithoutShell(nuget, args, p => p.StandardOutput.ReadToEnd());
            }
            else
            {
                var args = string.Format("sources add -name \"{0}\" -source \"{1} \"", name, source);
                return StartProcessWithoutShell(nuget, args, p => p.StandardOutput.ReadToEnd());
            }
        }

        public bool HaveAddedSources(string name)
        {
            var nuget = EnvironmentRepository.GetNuGetPath();
            var args = "sources list";
            var nameRecordRegex = new Regex(@"^\s+\d+\.\s+");
            var nameExtractRegex = new Regex(@"^\s+\d+\.\s+(?<name>.*)( \[[^\]]+\])$", RegexOptions.IgnoreCase);
            var nameRegex = new Regex(string.Format(@"^{0}$", Regex.Escape(name)), RegexOptions.IgnoreCase);
            return StartProcessWithoutShell(nuget, args, p => p.StandardOutput.ReadLines().
                        Where(_ => nameRecordRegex.IsMatch(_)).
                        Select(_ => nameExtractRegex.Replace(_, @"${name}")).
                        Any(_ => nameRegex.IsMatch(_))
                   );
        }

        public string StartUnsourcing(string name)
        {
            if (!HaveAddedSources(name))
                return string.Format("The specified sources '{0}' don't exist.", name);

            var nuget = EnvironmentRepository.GetNuGetPath();
            var args = string.Format("sources remove -name \"{0}\"", name);
            return StartProcessWithoutShell(nuget, args, p => p.StandardOutput.ReadToEnd());
        }
    }
}
