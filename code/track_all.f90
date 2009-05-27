!+                       
! Subroutine track_all (lat, orbit, ix_branch)
!
! Subroutine to track through the lat.
!
! Note: If x_limit (or y_limit) for an element is zero then track_all will take
!       x_limit (or y_limit) as infinite.
!
! Note: If a particle does not make it through an lcavity because of lack of
!       sufficient energy, then orbit(ix_lost)%vec(6) will be < -1. 
!
! Modules Needed:
!   use bmad
!
! Input:
!   lat       -- lat_struct: Lat to track through.
!     %param%aperture_limit_on -- Logical: Sets whether track_all looks to
!                                 see whether a particle hits an aperture or not.
!   orbit(0)  -- Coord_struct: Coordinates at beginning of lat.
!   ix_branch -- Integer, optional: Branch to track. Default is 0 (main lattice).
!
! Output:
!   lat
!     %param -- Param_struct.
!       %lost          -- Logical: Set True when a particle cannot make it 
!                           through an element.
!       %ix_lost       -- Integer: Set to index of element where particle is lost.
!       %plane_lost_at -- x_plane$, y_plane$ (for apertures), or 
!                           z_plane$ (turned around in an lcavity).
!       %end_lost_at   -- entrance_end$ or exit_end$.
!   orbit(0:*)  -- Coord_struct: Orbit array.
!-

#include "CESR_platform.inc"

subroutine track_all (lat, orbit, ix_branch)

  use bmad_struct
  use bmad_interface, except_dummy => track_all
  use bookkeeper_mod, only: control_bookkeeper

  implicit none

  type (lat_struct)  lat
  type (coord_struct), allocatable :: orbit(:)

  integer n, i, nn, ix_br
  integer, optional :: ix_branch

  logical :: debug = .false.

! init

  ix_br = integer_option (0, ix_branch)
  if (size(orbit) < lat%branch(ix_br)%n_ele_max+1) call reallocate_coord (orbit, lat%branch(ix_br)%n_ele_max)

  lat%param%ix_lost = not_lost$

  if (bmad_com%auto_bookkeeper) call control_bookkeeper (lat)

! track through elements.

  do n = 1, lat%branch(ix_br)%n_ele_track

    call track1 (orbit(n-1), lat%branch(ix_br)%ele(n), lat%param, orbit(n))

! check for lost particles

    if (lat%param%lost) then
      lat%param%ix_lost = n
      do nn = n+1, lat%branch(ix_br)%n_ele_track
        orbit(nn)%vec = 0
      enddo
      return
    endif

    if (debug) then
      print *, lat%branch(ix_br)%ele(n)%name
      print *, (orbit(n)%vec(i), i = 1, 6)
    endif

  enddo

end subroutine
