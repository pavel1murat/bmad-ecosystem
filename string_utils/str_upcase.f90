!+
! Subroutine str_upcase (destination, source)
!
! Subroutine to convert a string to upper case.
!
! Modules needed:
!   use cesr_interface
!
! Input:
!   source -- Character(*): Source string.
!
! Output:
!   destination -- Character(*): Upper cased string.
!-

#include "CESR_platform.inc"

subroutine str_upcase(dst, src)
  implicit none
  
  character*(*) dst,src
  integer i,s,dlen,slen
  
  dlen=len(dst)
  slen=len(src)
  i=1
  do i=1,dlen
     if (i.le.slen) then
        s=ichar(src(i:i))
        if (s.ge.97.and.s.le.122) then
           s=s-32
        endif
        dst(i:i)=char(s)
     else
        dst(i:i)=' '
     endif
  enddo
end subroutine str_upcase


