!+
! Subroutine concat_taylor (taylor1, taylor2, taylor3)
! 
! Subroutine to concatinate two taylor series.
!
! Modules needed:
!   use bmad
!
! Input:
!   taylor1(6) -- Taylor_struct: Taylor series.
!   taylor2(6) -- Taylor_struct: Taylor series.
!
! Output
!   taylor3(6) -- Taylor_struct: Concatinated series
!-

subroutine concat_taylor (taylor1, taylor2, taylor3)

  use accelerator
  
  implicit none

  type (taylor_struct), intent(in) :: taylor1(:), taylor2(:)
  type (taylor_struct), intent(out) :: taylor3(:)
  type (real_8) y1(6), y2(6), y3(6)
  type (damap) da1, da2, da3

! Allocate temp vars

  call real_8_init (y1)
  call real_8_init (y2)
  call real_8_init (y3)

! concat

  y1 = taylor1
  y2 = taylor2

  call concat_real_8 (y1, y2, y3)

  taylor3 = y3
  taylor3(:)%ref = taylor1(:)%ref

!

  call kill (y1)
  call kill (y2)
  call kill (y3)

end subroutine  
  
