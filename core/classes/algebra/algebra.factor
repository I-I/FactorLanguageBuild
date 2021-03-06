! Copyright (C) 2004, 2010 Slava Pestov.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs classes classes.private
combinators kernel math math.order namespaces sequences sorting
vectors words ;
FROM: classes => members ;
RENAME: members sets => set-members
IN: classes.algebra

<PRIVATE

TUPLE: anonymous-union { members read-only } ;

INSTANCE: anonymous-union classoid

: <anonymous-union> ( members -- class )
    [ null eq? not ] filter set-members
    dup length 1 = [ first ] [ anonymous-union boa ] if ;

M: anonymous-union rank-class drop 6 ;

TUPLE: anonymous-intersection { participants read-only } ;

INSTANCE: anonymous-intersection classoid

: <anonymous-intersection> ( participants -- class )
    set-members dup length 1 =
    [ first ] [ anonymous-intersection boa ] if ;

M: anonymous-intersection rank-class drop 4 ;

TUPLE: anonymous-complement { class read-only } ;

INSTANCE: anonymous-complement classoid

C: <anonymous-complement> anonymous-complement

M: anonymous-complement rank-class drop 3 ;

DEFER: (class<=)

DEFER: (class-not)

GENERIC: (classes-intersect?) ( first second -- ? )

DEFER: (class-and)

DEFER: (class-or)

GENERIC: (flatten-class) ( class -- )

GENERIC: normalize-class ( class -- class' )

M: object normalize-class ;

: symmetric-class-op ( first second cache quot -- result )
    [ 2dup [ rank-class ] bi@ > [ swap ] when ] 2dip 2cache ; inline

PRIVATE>

GENERIC: valid-classoid? ( obj -- ? )

M: word valid-classoid? class? ;
M: anonymous-union valid-classoid? members>> [ valid-classoid? ] all? ;
M: anonymous-intersection valid-classoid? participants>> [ valid-classoid? ] all? ;
M: anonymous-complement valid-classoid? class>> valid-classoid? ;
M: object valid-classoid? drop f ;

: only-classoid? ( obj -- ? )
    [ classoid? ] [ class? not ] bi and ;

: class<= ( first second -- ? )
    class<=-cache get [ (class<=) ] 2cache ;

: class< ( first second -- ? )
    {
        { [ 2dup class<= not ] [ 2drop f ] }
        { [ 2dup swap class<= not ] [ 2drop t ] }
        [ [ rank-class ] bi@ < ]
    } cond ;

: class= ( first second -- ? )
    [ class<= ] [ swap class<= ] 2bi and ;

: class-not ( class -- complement )
    class-not-cache get [ (class-not) ] cache ;

: classes-intersect? ( first second -- ? )
    [ normalize-class ] bi@
    classes-intersect-cache get [ (classes-intersect?) ] symmetric-class-op ;

: class-and ( first second -- class )
    class-and-cache get [ (class-and) ] symmetric-class-op ;

: class-or ( first second -- class )
    class-or-cache get [ (class-or) ] symmetric-class-op ;

SYMBOL: +incomparable+

: compare-classes ( first second -- <=> )
    [ swap class<= ] [ class<= ] 2bi
    [ +eq+ +lt+ ] [ +gt+ +incomparable+ ] if ? ;

: evaluate-class-predicate ( class1 class2 -- ? )
    {
        { [ 2dup class<= ] [ t ] }
        { [ 2dup classes-intersect? not ] [ f ] }
        [ +incomparable+ ]
    } cond 2nip ;

<PRIVATE

: superclass<= ( first second -- ? )
    swap superclass dup [ swap class<= ] [ 2drop f ] if ;

: left-anonymous-union<= ( first second -- ? )
    [ members>> ] dip [ class<= ] curry all? ;

: right-union<= ( first second -- ? )
    members [ class<= ] with any? ;

: right-anonymous-union<= ( first second -- ? )
    members>> [ class<= ] with any? ;

: left-anonymous-intersection<= ( first second -- ? )
    [ participants>> ] dip [ class<= ] curry any? ;

PREDICATE: nontrivial-anonymous-intersection < anonymous-intersection
    participants>> empty? not ;

: right-anonymous-intersection<= ( first second -- ? )
    participants>> [ class<= ] with all? ;

: anonymous-complement<= ( first second -- ? )
    [ class>> ] bi@ swap class<= ;

: normalize-complement ( class -- class' )
    class>> normalize-class {
        { [ dup anonymous-union? ] [
            members>>
            [ class-not normalize-class ] map
            <anonymous-intersection> 
        ] }
        { [ dup anonymous-intersection? ] [
            participants>>
            [ class-not normalize-class ] map
            <anonymous-union>
        ] }
        [ drop object ]
    } cond ;

: left-anonymous-complement<= ( first second -- ? )
    [ normalize-complement ] dip class<= ;

PREDICATE: nontrivial-anonymous-complement < anonymous-complement
    class>> {
        [ anonymous-union? ]
        [ anonymous-intersection? ]
        [ members ]
        [ participants ]
    } cleave or or or ;

PREDICATE: empty-union < anonymous-union members>> empty? ;

PREDICATE: empty-intersection < anonymous-intersection participants>> empty? ;

: (class<=) ( first second -- ? )
    2dup eq? [ 2drop t ] [
        [ normalize-class ] bi@
        2dup superclass<= [ 2drop t ] [
            {
                { [ 2dup eq? ] [ 2drop t ] }
                { [ dup empty-intersection? ] [ 2drop t ] }
                { [ over empty-union? ] [ 2drop t ] }
                { [ 2dup [ anonymous-complement? ] both? ] [ anonymous-complement<= ] }
                { [ over anonymous-union? ] [ left-anonymous-union<= ] }
                { [ over nontrivial-anonymous-intersection? ] [ left-anonymous-intersection<= ] }
                { [ over nontrivial-anonymous-complement? ] [ left-anonymous-complement<= ] }
                { [ dup members ] [ right-union<= ] }
                { [ dup anonymous-union? ] [ right-anonymous-union<= ] }
                { [ dup anonymous-intersection? ] [ right-anonymous-intersection<= ] }
                { [ dup anonymous-complement? ] [ class>> classes-intersect? not ] }
                [ 2drop f ]
            } cond
        ] if
    ] if ;

M: anonymous-union (classes-intersect?)
    members>> [ classes-intersect? ] with any? ;

M: anonymous-intersection (classes-intersect?)
    participants>> [ classes-intersect? ] with all? ;

M: anonymous-complement (classes-intersect?)
    class>> class<= not ;

: anonymous-union-and ( first second -- class )
    members>> [ class-and ] with map <anonymous-union> ;

: anonymous-intersection-and ( first second -- class )
    participants>> swap suffix <anonymous-intersection> ;

: (class-and) ( first second -- class )
    2dup compare-classes {
        { +lt+ [ drop ] }
        { +gt+ [ nip ] }
        { +eq+ [ nip ] }
        { +incomparable+ [
            2dup classes-intersect? [
                [ normalize-class ] bi@ {
                    { [ dup anonymous-union? ] [ anonymous-union-and ] }
                    { [ dup anonymous-intersection? ] [ anonymous-intersection-and ] }
                    { [ over anonymous-union? ] [ swap anonymous-union-and ] }
                    { [ over anonymous-intersection? ] [ swap anonymous-intersection-and ] }
                    [ 2array <anonymous-intersection> ]
                } cond
            ] [ 2drop null ] if
        ] }
    } case ;

: anonymous-union-or ( first second -- class )
    members>> swap suffix <anonymous-union> ;

: ((class-or)) ( first second -- class )
    [ normalize-class ] bi@ {
        { [ dup anonymous-union? ] [ anonymous-union-or ] }
        { [ over anonymous-union? ] [ swap anonymous-union-or ] }
        [ 2array <anonymous-union> ]
    } cond ;

: anonymous-complement-or ( first second -- class )
    2dup class>> swap class<= [ 2drop object ] [ ((class-or)) ] if ;

: (class-or) ( first second -- class )
    2dup compare-classes {
        { +lt+ [ nip ] }
        { +gt+ [ drop ] }
        { +eq+ [ nip ] }
        { +incomparable+ [
            {
                { [ dup anonymous-complement? ] [ anonymous-complement-or ] }
                { [ over anonymous-complement? ] [ swap anonymous-complement-or ] }
                [ ((class-or)) ]
            } cond
        ] }
    } case ;

: (class-not) ( class -- complement )
    {
        { [ dup anonymous-complement? ] [ class>> ] }
        { [ dup object eq? ] [ drop null ] }
        { [ dup null eq? ] [ drop object ] }
        [ <anonymous-complement> ]
    } cond ;

M: anonymous-union (flatten-class)
    members>> [ (flatten-class) ] each ;

PRIVATE>

ERROR: topological-sort-failed ;

: largest-class ( seq -- n elt )
    dup [ [ class< ] with any? not ] curry find-last
    [ topological-sort-failed ] unless* ;

: sort-classes ( seq -- newseq )
    [ class-name ] sort-with >vector
    [ dup empty? not ]
    [ dup largest-class [ swap remove-nth! ] dip ]
    produce nip ;

: smallest-class ( classes -- class/f )
    [ f ] [
        natural-sort <reversed>
        [ ] [ [ class<= ] most ] map-reduce
    ] if-empty ;

: flatten-class ( class -- assoc )
    [ (flatten-class) ] H{ } make-assoc ;
