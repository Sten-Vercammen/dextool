/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

File for handling the db connection
*/
module mutantschemata.db_handler;

import miniorm : Miniorm, buildSchema, delete_, insert, select;
import dextool.type: Path;

import std.range: front;
import std.array: array, empty;

import logger = std.experimental.logger;

struct DBHandler {
    private Miniorm db;

    this(Path dbPath) {
        db = Miniorm(dbPath);
    }

    void insertInDB(T)(T t) {
        db.run(insert!T.insert, t);
    }
    T[] selectFromDB(T)(string condition = "") {
        auto query = (condition != "") ? db.run(select!T.where(condition)) : db.run(select!T);
        return query.array;
    }
    void buildSchemaDB(T)() {
        db.run(buildSchema!T);
    }
    void deleteInDB(T)(string condition = "") {
        (condition != "") ? db.run(delete_!T.where(condition)) : db.run(delete_!T);
    }
    void closeDB() {
        db.close();
    }
}
