﻿/* 
 * File: PDateTimeTest.cs
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



#if NUnit
using TestFixtureAttribute = NUnit.Framework.TestFixtureAttribute;
using TestAttribute = NUnit.Framework.TestAttribute;
#elif MsTest
using TestFixtureAttribute = Microsoft.VisualStudio.TestTools.UnitTesting.TestClassAttribute;
using TestAttribute = Microsoft.VisualStudio.TestTools.UnitTesting.TestMethodAttribute;
#endif
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Prig;
using System.Reflection;
using Urasandesu.Prig.Framework;
using Test.program1.TestUtilities;

namespace Test.program1.System.Prig
{
    [TestFixture]
    public class PDateTimeTest
    {
        [Test]
        public void GetterOfNow_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                PDateTime.NowGet().Body = () => new DateTime(2014, 02, 14, 11, 30, 55, 00);

                // Act
                var actual = DateTime.Now;

                // Assert
                Assert.AreEqual(new DateTime(2014, 02, 14, 11, 30, 55, 00), actual);
            }
        }

        [Test]
        public void GetterOfNow_should_be_callable_originally_any_time()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                var count = 0;
                PDateTime.NowGet().Body = () =>
                {
                    if (5 <= ++count)
                        return new DateTime(2013, 12, 23, 11, 22, 33, 44);
                    else
                        return IndirectionsContext.ExecuteOriginal(() => DateTime.Now);
                };

                // Act
                var actuals = new List<DateTime>();
                actuals.Add(DateTime.Now);
                actuals.Add(DateTime.Now);
                actuals.Add(DateTime.Now);
                actuals.Add(DateTime.Now);
                actuals.Add(DateTime.Now);
                actuals.Add(DateTime.Now);

                // Assert
                var indirectValue = new DateTime(2013, 12, 23, 11, 22, 33, 44);
                Assert.AreNotEqual(indirectValue, actuals[0]);
                Assert.AreNotEqual(indirectValue, actuals[1]);
                Assert.AreNotEqual(indirectValue, actuals[2]);
                Assert.AreNotEqual(indirectValue, actuals[3]);
                Assert.AreEqual(indirectValue, actuals[4]);
                Assert.AreEqual(indirectValue, actuals[5]);
            }
        }

        [Test]
        public void FromBinary_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                PDateTime.FromBinaryInt64().Body = _ => new DateTime(2014, 12, 23, 01, 02, 03, 00);

                // Act
                var dateData = DateTime.Now.ToBinary();
                var actual = DateTime.FromBinary(dateData);
                
                // Assert
                Assert.AreEqual(new DateTime(2014, 12, 23, 01, 02, 03, 00), actual);
            }
        }

        [Test]
        public void DoubleDateToTicks_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                PDateTime.DoubleDateToTicksDouble().Body = value => 635233945530440000L;

                // Act
                var oaDate = DateTime.Now.ToOADate();
                var actual = new DateTime(DateTimeMixin.DoubleDateToTicks(oaDate), DateTimeKind.Unspecified);

                // Assert
                Assert.AreEqual(new DateTime(2013, 12, 23, 11, 22, 33, 44), actual);
            }
        }
        
        [Test]
        public void TryParseStringDateTimeFormatInfoDateTimeStylesDateTimeRef_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                PDateTimeParse.TryParseStringDateTimeFormatInfoDateTimeStylesDateTimeRef().Body = (string s, DateTimeFormatInfo dtfi, DateTimeStyles styles, out DateTime result) =>
                {
                    result = new DateTime(2014, 02, 14, 11, 30, 55, 00);
                    return true;
                };

                // Act
                var actualResult = default(DateTime);
                var actualReturn = DateTime.TryParse(DateTime.Now.ToString("yyyyMMddHHmmss"), new CultureInfo("en-us"), DateTimeStyles.None, out actualResult);

                // Assert
                Assert.IsTrue(actualReturn);
                Assert.AreEqual(new DateTime(2014, 02, 14, 11, 30, 55, 00), actualResult);
            }
        }

        [Test]
        public void TryParseStringDateTimeFormatInfoDateTimeStylesDateTimeResultRef_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                var dateTimeParse = typeof(DateTime).Assembly.GetTypes().First(_ => _.Name == "DateTimeParse");
                var dateTimeResult = typeof(DateTime).Assembly.GetTypes().First(_ => _.Name == "DateTimeResult");
                var dateTimeParse_TryParse = dateTimeParse.GetMethod("TryParse",
                                                                     BindingFlags.NonPublic |
                                                                     BindingFlags.Static,
                                                                     null,
                                                                     new[] { typeof(string), typeof(DateTimeFormatInfo), typeof(DateTimeStyles), dateTimeResult.MakeByRefType() },
                                                                     null);
                var expected = Activator.CreateInstance(dateTimeResult);

                PDateTimeParse.TryParseStringDateTimeFormatInfoDateTimeStylesDateTimeResultRef().Body = args => { args[3] = expected; return true; };


                // Act
                var @params = new object[] { "aiueo", new DateTimeFormatInfo(), DateTimeStyles.None, null };
                var result = dateTimeParse_TryParse.Invoke(null, @params);


                // Assert
                Assert.AreEqual(true, result);
                Assert.IsNotNull(@params[3]);
            }
        }

        [Test]
        public void CompareTo_should_be_callable_indirectly()
        {
            using (new IndirectionsContext())
            {
                // Arrange
                PDateTime.CompareToObject().Body = (ref DateTime @this, object value) => ((DateTime)value).CompareTo(new DateTime(2013, 12, 23));

                // Act
                var actual = DateTime.Now.CompareTo((object)new DateTime(2013, 12, 23));

                // Assert
                Assert.AreEqual(0, actual);
            }
        }
    }

    public static class DateTimeMixin
    {
        public static long DoubleDateToTicks(double value)
        {
            var doubleDateToTicksInfo = typeof(DateTime).GetMethod("DoubleDateToTicks", BindingFlags.NonPublic | BindingFlags.Static);
            return (long)doubleDateToTicksInfo.Invoke(null, new object[] { value });
        }
    }
}
