
/* this is a wrong specification. */
/* this function doesn't create an integer in memory */

/*@
predicate (integer) Owned_Wrapper (pointer p) {
  take I = Owned<int>(p);
  return I;
}
@*/

int
f (int *p, int x)
/*@ requires x < 12 @*/
/*@ ensures return < 12 @*/
/*@ ensures take Resource_From_Nothing = Owned_Wrapper(p) @*/
{
  return x;
}



