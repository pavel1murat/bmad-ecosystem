!+
! Subroutine track1_runge_kutta (start, ele, param, end, track)
!
! Subroutine to do tracking using Runge-Kutta integration. 
! The core Runge-Kutta routine used here is odeint_bmad which is
! a modified version of odeint from Numerical Recipes.
! See the "Numerical Recipes in F90" book.
!
! Modules needed:
!   use bmad
!
! Input:
!   start      -- Coord_struct: Starting coords.
!   ele        -- Ele_struct
!   param      -- lat_param_struct: Beam parameters.
!     %enegy     -- Energy in GeV
!     %particle  -- Particle type [positron$, or electron$]
!   track      -- Track_struct: Structure holding the track information.
!     %save_track -- Logical: Set True if track is to be saved.
!
!   bmad_com -- Bmad common block.
!     %rel_tol_adaptive_tracking -- Relative tolerance. Default is 1e-6.
!     %abs_tol_adaptive_tracking -- Absolute tolerance. Default is 1e-7.
!
! Output:
!   end        -- Coord_struct: Ending coords.
!     %vec(5)     = s_len - path_length where s_len = s_end-s_start. 
!                  Thus for a wiggler, where the "zero" orbit path_length 
!                  is not s_len, there needs to be a correction term:
!                    end%vec(5) = end%vec(5) + zero_orbit_path_length - s_len
!   track      -- Track_struct: Structure holding the track information.
!- 

subroutine track1_runge_kutta (start, ele, param, end, track)

use runge_kutta_mod, except_dummy => track1_runge_kutta

implicit none

type (coord_struct) :: start
type (coord_struct) :: end
type (lat_param_struct), target, intent(inout) :: param
type (ele_struct), target, intent(inout) :: ele
type (track_struct) track

real(rp) rel_tol, abs_tol, del_s_step, del_s_min

! Track.
! Remember: offset_particle converts from cononical momentum P_x, P_y to x', y'

del_s_step = 1e-3
del_s_min = 1e-8

call offset_particle (ele, param, end, set$)
call odeint_bmad (start, ele, param, end, 0.0_rp, ele%value(l$), &
        bmad_com%rel_tol_adaptive_tracking, bmad_com%abs_tol_adaptive_tracking, &
        del_s_step, del_s_min, .true., track)
call offset_particle (ele, param, end, unset$)

end subroutine
