! useful chars = 11 + 12 + 25 + 8 + 3 + 6 + 17 + 5 + 3 = 90
! useful lines = 9
! total lines = 18
      program test
      integer a(13)
!dvm$ distribute (block) :: a
!!dvm$ distribute (block) :: b
c comment after C
      ! comment
      integer c
      c = 0
      print *
     x, 'Hello, world!'                                                 after 72 comment

      c = c + 1
*another comment
      end! end of program

