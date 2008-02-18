! Copyright (C) 2005, 2008 Chris Double, Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: alien arrays assocs classes compiler db
hashtables io.files kernel math math.parser namespaces
prettyprint sequences strings tuples alien.c-types
continuations db.sqlite.lib db.sqlite.ffi db.tuples
words combinators.lib db.types ;
IN: db.sqlite

TUPLE: sqlite-db path ;
C: <sqlite-db> sqlite-db

M: sqlite-db db-open ( db -- )
    dup sqlite-db-path sqlite-open <db>
    swap set-delegate ;

M: sqlite-db db-close ( handle -- )
    sqlite-close ;

M: sqlite-db dispose ( db -- ) dispose-db ;

: with-sqlite ( path quot -- )
    >r <sqlite-db> r> with-db ; inline

TUPLE: sqlite-statement ;
C: <sqlite-statement> sqlite-statement

TUPLE: sqlite-result-set has-more? ;

M: sqlite-db <simple-statement> ( str -- obj )
    <prepared-statement> ;

M: sqlite-db <prepared-statement> ( str -- obj )
    db get db-handle over sqlite-prepare
    { set-statement-sql set-statement-handle } statement construct
    <sqlite-statement> [ set-delegate ] keep ;

M: sqlite-statement dispose ( statement -- )
    statement-handle sqlite-finalize ;

M: sqlite-result-set dispose ( result-set -- )
    f swap set-result-set-handle ;

: sqlite-bind ( triples handle -- )
    swap [ first3 sqlite-bind-type ] with each ;

M: sqlite-statement bind-statement* ( triples statement -- )
    statement-handle sqlite-bind ;

M: sqlite-statement reset-statement ( statement -- )
    statement-handle sqlite-reset ;

: last-insert-id ( -- id )
    db get db-handle sqlite3_last_insert_rowid
    dup zero? [ "last-id failed" throw ] when ;

M: sqlite-statement insert-statement ( statement -- id )
    execute-statement last-insert-id ;

M: sqlite-result-set #columns ( result-set -- n )
    result-set-handle sqlite-#columns ;

M: sqlite-result-set row-column ( result-set n -- obj )
    >r result-set-handle r> sqlite-column ;

M: sqlite-result-set row-column-typed ( result-set n type -- obj )
    >r result-set-handle r> sqlite-column-typed ;

M: sqlite-result-set advance-row ( result-set -- )
    [ result-set-handle sqlite-next ] keep
    set-sqlite-result-set-has-more? ;

M: sqlite-result-set more-rows? ( result-set -- ? )
    sqlite-result-set-has-more? ;

M: sqlite-statement query-results ( query -- result-set )
    dup statement-handle sqlite-result-set <result-set>
    dup advance-row ;

M: sqlite-db begin-transaction ( -- )
    "BEGIN" sql-command ;

M: sqlite-db commit-transaction ( -- )
    "COMMIT" sql-command ;

M: sqlite-db rollback-transaction ( -- )
    "ROLLBACK" sql-command ;

M: sqlite-db create-sql ( columns table -- sql )
    [
        "create table " % %
        " (" % [ ", " % ] [
            dup second % " " %
            dup third >sql-type % " " %
            sql-modifiers " " join %
        ] interleave ")" %
    ] "" make ;

M: sqlite-db drop-sql ( columns table -- sql )
    [
        "drop table " % %
        drop
    ] "" make ;

M: sqlite-db insert-sql* ( columns table -- sql )
    [
        "insert into " %
        %
        "(" %
        dup [ ", " % ] [ second % ] interleave
        ") " %
        " values (" %
        [ ", " % ] [ ":" % second % ] interleave
        ")" %
    ] "" make ;

: where-primary-key% ( columns -- )
    " where " %
    [ primary-key? ] find nip second dup % " = :" % % ;

M: sqlite-db update-sql* ( columns table -- sql )
    [
        "update " %
        %
        " set " %
        dup remove-id
        [ ", " % ] [ second dup % " = :" % % ] interleave
        where-primary-key%
    ] "" make ;

M: sqlite-db delete-sql* ( columns table -- sql )
    [
        "delete from " %
        %
        " where " %
        first second dup % " = :" % %
    ] "" make ;

: select-interval ( interval name -- )
    ;

: select-sequence ( seq name -- )
    ;

M: sqlite-db select-sql ( columns table -- sql )
    [
        "select ROWID, " %
        over [ ", " % ] [ second % ] interleave
        " from " % %
        " where " %
    ] "" make ;

M: sqlite-db tuple>params ( columns tuple -- obj )
    [
        >r [ second ":" swap append ] keep r>
        dupd >r first r> get-slot-named swap
        third 3array
    ] curry map ;

: sqlite-db-modifiers ( -- hashtable )
    H{
        { +native-id+ "primary key" }
        { +assigned-id+ "primary key" }
        { +autoincrement+ "autoincrement" }
        { +unique+ "unique" }
        { +default+ "default" }
        { +null+ "null" }
        { +not-null+ "not null" }
    } ;

M: sqlite-db sql-modifiers* ( modifiers -- str )
    sqlite-db-modifiers swap [
        dup array? [
            first2
            >r swap at r> number>string*
            " " swap 3append
        ] [
            swap at
        ] if
    ] with map [ ] subset ;

: sqlite-type-hash ( -- assoc )
    H{
        { INTEGER "integer" }
        { SERIAL "integer" }
        { TEXT "text" }
        { VARCHAR "text" }
        { DOUBLE "real" }
    } ;

M: sqlite-db >sql-type ( obj -- str )
    dup pair? [
        first >sql-type
    ] [
        sqlite-type-hash at* [ T{ no-sql-type } throw ] unless
    ] if ;

! HOOK: get-column-value ( n result-set type -- )
! M: sqlite get-column-value { { "TEXT" get-text-column } { 
! "INTEGER" get-integer-column } ... } case ;
