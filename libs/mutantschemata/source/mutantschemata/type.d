/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.


Types created for specific use in the mutant schemata API
*/
module mutantschemata.type;

import mutantschemata.externals;

struct SchemataFileString {
    string fpath;
    SchemataMutant[] mutants;
    string code;
}