/// Written in the D programming language.
/// Date: 2015, Joakim Brännström
/// License: GPL
/// Author: Joakim Brännström (joakim.brannstrom@gmx.com)
///
/// This program is free software; you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation; either version 2 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program; if not, write to the Free Software
/// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
module test.helpers;
import unit_threaded;

import std.ascii : newline;
import std.traits : isSomeString;

import unit_threaded : name;

version (unittest) {
    import unit_threaded : shouldEqual;
}

/**
 * Verify in lockstep that the two values are the same.
 * Useful when the values can be treated as ranges.
 * The lockstep comparison then results in a more comprehensible failure
 * message.
 *
 * Throws: UnitTestException on failure
 * Params:
 *  value = actual value.
 *  expected = expected value.
 *  file = file check is in.
 *  line = line check is on.
 * dfmt off
 */
void shouldEqualPretty(V, E, string file = __FILE__, ulong line = __LINE__)(V value, E expected) {
    //dfmt on
    import std.algorithm : count;
    import std.range : lockstep;
    import unit_threaded : shouldEqual;

    foreach (index, val, exp; lockstep(value, expected)) {
        shouldEqual(val, exp, file, line);
    }

    shouldEqual(count(value), count(expected), file, line);
}

@name("shouldEqualPretty should throw the first value that is different")
unittest {
    import unit_threaded : UnitTestException;

    string msg;
    try {
        auto value = [0, 2, 1];
        auto expected = [0, 1, 2];
        shouldEqualPretty!(typeof(value), typeof(expected), "file.d", 123)(value, expected);

        assert(false, "Didn't throw exception");
    }
    catch (UnitTestException ex) {
        msg = ex.toString;
    }
    //shouldEqualPretty(msg, "foo");
    shouldEqual(msg, "foo");
}

/**
 * Split with sep and verify in lockstep that the two values are the same.
 *
 * Throws: UnitTestException on failure.
 * Params:
 *  value = actual value.
 *  expected = expected value.
 *  sep = separator to split value and expected on.
 *  file = file check is in.
 *  line = line check is on.
 *
 *  dfmt off
 */
void shouldEqualPretty(V, E, Separator, string file = __FILE__, ulong line= __LINE__)(V value, E expected, Separator sep)
    if (!isAllSomeString!(V, E))
{
    //dfmt on
    import std.algorithm : count;
    import std.range : lockstep;
    import unit_threaded : shouldEqual;
    import std.algorithm : splitter;

    auto rValue = value.splitter(sep);
    auto rExpected = expected.splitter(sep);

    shouldEqualPretty!(typeof(rValue), typeof(rExpected), file, line)(rValue, rExpected);
}

/**
 * Verify that two strings are the same.
 * Performs tests per line to better isolate when a difference is found.
 *
 * Throws: UnitTestException on failure
 * Params:
 *  value = actual value.
 *  expected = expected value.
 *  file = file check is in.
 *  line = line check is on.
 *
 * dfmt off
 */
void shouldEqualPretty(V, E, string file = __FILE__, ulong line = __LINE__)(V value, E expected, string sep = newline)
    if (isAllSomeString!(V, E))
{
    // dfmt on
    import std.algorithm : splitter;

    auto rValue = value.splitter(sep);
    auto rExpected = expected.splitter(sep);

    shouldEqualPretty!(typeof(rValue), typeof(rExpected), file, line)(rValue, rExpected);
}

private:
enum isAllSomeString(T0, T1) = isSomeString!T0 && isSomeString!T1;
