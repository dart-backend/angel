part of lex.src.combinator;

/// A typed parser that parses a sequence of 2 values of different types.
Parser<Tuple2<A, B>> tuple2<A, B>(Parser<A> a, Parser<B> b) {
  return chain([a, b]).map((r) {
    return Tuple2(r.value[0] as A, r.value[1] as B);
  });
}

/// A typed parser that parses a sequence of 3 values of different types.
Parser<Tuple3<A, B, C>> tuple3<A, B, C>(Parser<A> a, Parser<B> b, Parser<C> c) {
  return chain([a, b, c]).map((r) {
    return Tuple3(r.value[0] as A, r.value[1] as B, r.value[2] as C);
  });
}

/// A typed parser that parses a sequence of 4 values of different types.
Parser<Tuple4<A, B, C, D>> tuple4<A, B, C, D>(
    Parser<A> a, Parser<B> b, Parser<C> c, Parser<D> d) {
  return chain([a, b, c, d]).map((r) {
    return Tuple4(
        r.value[0] as A, r.value[1] as B, r.value[2] as C, r.value[3] as D);
  });
}

/// A typed parser that parses a sequence of 5 values of different types.
Parser<Tuple5<A, B, C, D, E>> tuple5<A, B, C, D, E>(
    Parser<A> a, Parser<B> b, Parser<C> c, Parser<D> d, Parser<E> e) {
  return chain([a, b, c, d, e]).map((r) {
    return Tuple5(r.value[0] as A, r.value[1] as B, r.value[2] as C,
        r.value[3] as D, r.value[4] as E);
  });
}

/// A typed parser that parses a sequence of 6 values of different types.
Parser<Tuple6<A, B, C, D, E, F>> tuple6<A, B, C, D, E, F>(Parser<A> a,
    Parser<B> b, Parser<C> c, Parser<D> d, Parser<E> e, Parser<F> f) {
  return chain([a, b, c, d, e, f]).map((r) {
    return Tuple6(r.value[0] as A, r.value[1] as B, r.value[2] as C,
        r.value[3] as D, r.value[4] as E, r.value[5] as F);
  });
}

/// A typed parser that parses a sequence of 7 values of different types.
Parser<Tuple7<A, B, C, D, E, F, G>> tuple7<A, B, C, D, E, F, G>(
    Parser<A> a,
    Parser<B> b,
    Parser<C> c,
    Parser<D> d,
    Parser<E> e,
    Parser<F> f,
    Parser<G> g) {
  return chain([a, b, c, d, e, f, g]).map((r) {
    return Tuple7(r.value[0] as A, r.value[1] as B, r.value[2] as C,
        r.value[3] as D, r.value[4] as E, r.value[5] as F, r.value[6] as G);
  });
}
