! useful chars = 11 + 12 + 25 + 8 + 3 + 7 + 16 + 5 + 3 = 90
! useful lines = 9
! tlines = 18
program test
      integer a(13)
      !dvm$ distribute (block) :: a
!!dvm$ distribute (block) :: b
! comment after !
      ! comment
integer c
c = 0
print * &
, 'Hello, world!' ! after line comment

c = c + 1
!another comment
end! end of program

