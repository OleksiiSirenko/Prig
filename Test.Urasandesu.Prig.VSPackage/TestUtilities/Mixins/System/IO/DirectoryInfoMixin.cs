﻿/* 
 * File: DirectoryInfoMixin.cs
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



using Ploeh.AutoFixture;
using System;
using System.IO;
using System.Linq;
using System.Security.AccessControl;
using System.Security.Principal;

namespace Test.Urasandesu.Prig.VSPackage.TestUtilities.Mixins.System.IO
{
    public static class DirectoryInfoMixin
    {
        public static DirectoryInfoModifyingBegun BeginModifying(this DirectoryInfo orgInfo)
        {
            var id = Guid.NewGuid().ToString("N");
            var bakInfo = new DirectoryInfo(orgInfo.FullName);
            var bakPath = orgInfo.FullName + "." + id + ".bak";
            if (bakInfo.Exists)
                bakInfo.MoveTo(bakPath);
            return new DirectoryInfoModifyingBegun(orgInfo, bakPath);
        }

        public static DirectoryInfo CreateWithContent(this DirectoryInfo info, IFixture fixture)
        {
            info.Create();
            var path = Path.Combine(info.FullName, fixture.Create<string>());
            using (var sw = new StreamWriter(new FileInfo(path).Open(FileMode.Create)))
                sw.WriteLine(fixture.Create<string>());
            return info;
        }

        public static bool HasUsersFullControlAccess(this DirectoryInfo info)
        {
            var accessCtrl = info.GetAccessControl(AccessControlSections.Access);
            var accessRules = accessCtrl.GetAccessRules(true, true, typeof(SecurityIdentifier)).OfType<FileSystemAccessRule>();
            var fullCtrlAccessRules = from accessRule in accessRules
                                      where accessRule.AccessControlType == AccessControlType.Allow
                                      where accessRule.IdentityReference == new SecurityIdentifier(WellKnownSidType.BuiltinUsersSid, null)
                                      where accessRule.FileSystemRights == FileSystemRights.FullControl
                                      select accessRule;
            return fullCtrlAccessRules.Any();
        }
    }
}
