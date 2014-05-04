﻿/* 
 * File: CommandFactory.h
 * 
 * Author: Akira Sugiura (urasandesu@gmail.com)
 * 
 * 
 * Copyright (c) 2014 Akira Sugiura
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


#pragma once
#ifndef PRIG_COMMANDFACTORY_H
#define PRIG_COMMANDFACTORY_H

#ifndef PRIG_HELPCOMMANDFWD_H
#include <prig/HelpCommandFwd.h>
#endif

#ifndef PRIG_RUNNERCOMMANDFWD_H
#include <prig/RunnerCommandFwd.h>
#endif

#ifndef PRIG_STUBBERCOMMANDFWD_H
#include <prig/StubberCommandFwd.h>
#endif

#ifndef PRIG_COMMANDFACTORYFWD_H
#include <prig/CommandFactoryFwd.h>
#endif

namespace prig { 

    namespace CommandFactoryDetail {

        using boost::program_options::options_description;
        using boost::shared_ptr;
        using std::wstring;

        class CommandFactoryImpl
        {
        public:
            static shared_ptr<HelpCommand> MakeHelpCommand(options_description const &desc);
            static shared_ptr<RunnerCommand> MakeRunnerCommand(wstring const &process, wstring const &arguments);
        };

    }   // namespace CommandFactoryDetail {

    struct CommandFactory : 
        CommandFactoryDetail::CommandFactoryImpl
    {
    };
    
}   // namespace prig { 

#endif  // PRIG_COMMANDFACTORY_H

