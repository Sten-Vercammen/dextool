/**
Copyright: Copyright (c) 2016, Joakim Brännström. All rights reserved.
License: MPL-2
Author: Joakim Brännström (joakim.brannstrom@gmx.com)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

DO NOT EDIT. THIS FILE IS GENERATED.
See the generator script source/devtool/generator_clang_ast_nodes.d
*/
module cpptooling.analyzer.clang.ast.directive;
import cpptooling.analyzer.clang.ast.node : Node;

abstract class Directive : Node {
    import clang.Cursor : Cursor;
    import cpptooling.analyzer.clang.ast : Visitor;

    Cursor cursor;
    alias cursor this;

    this(Cursor cursor) @safe {
        this.cursor = cursor;
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpParallelDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpSectionsDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpSectionDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpSingleDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpParallelForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpParallelSectionsDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpMasterDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpCriticalDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskyieldDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpBarrierDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskwaitDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpFlushDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpOrderedDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpAtomicDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpParallelForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTeamsDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskgroupDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpCancellationPointDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpCancelDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetDataDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskLoopDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTaskLoopSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpDistributeDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetEnterDataDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetExitDataDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetParallelDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetParallelForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetUpdateDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpDistributeParallelForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpDistributeParallelForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpDistributeSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetParallelForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTeamsDistributeDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTeamsDistributeSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTeamsDistributeParallelForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTeamsDistributeParallelForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetTeamsDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetTeamsDistributeDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetTeamsDistributeParallelForDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetTeamsDistributeParallelForSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}

final class OmpTargetTeamsDistributeSimdDirective : Directive {
    import clang.Cursor : Cursor;

    this(Cursor cursor) @safe {
        super(cursor);
    }

    override void accept(Visitor v) @safe const {
        static import cpptooling.analyzer.clang.ast;

        cpptooling.analyzer.clang.ast.accept(cursor, v);
    }
}
