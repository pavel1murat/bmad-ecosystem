module coord_mod

use basic_bmad_interface

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine init_coord (...)
!
! Routine to initialize a coord_struct. 
!
! This routine is an overloaded name for:
!   Subroutine init_coord1 (orb, vec, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)
!   Subroutine init_coord2 (orb, orb_in, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)
!
! Note: Unless shift_vec6 is set to False, if ele is a beginning_ele (IE, the element at the beginning of the lattice), 
! or e_gun, orb%vec(6) is shifted so that a particle with orb%vec(6) = 0 will end up with a value of orb%vec(6) 
! corresponding to the beginning_ele's value of ele%value(p0c_start$).
!
! Note: If the particle is initialized with element_end = inside$, orb%s will not be set.
!
! For photons:
!   orb%vec(5) is set depending upon where the photon is relative to the element.
!   If orb is a photon, and orb_in is not a photon, photon is launched in same direciton as particle 
!       except if direction is set.
!
! Modules needed:
!   use bmad
!
! Input:
!   orb_in       -- Coord_struct: Input orbit.
!   vec(6)       -- real(rp), optional: Coordinate vector. If not present then taken to be zero.
!   ele          -- ele_struct, optional: Particle is initialized to start from the entrance end of ele
!   element_end  -- integer, optional: upstream_end$, downstream_end$, inside$, or start_end$.
!                     Must be present if ele argument is present.
!                     start_end$ -> upstream_end$ if dir = 1 and start_end$ -> downstream_end$ if dir = -1.
!                     Default is upstream_end$.
!   particle     -- Integer, optional: Particle type (electron$, etc.). 
!                     If particle = not_set$ and orb_in is present, use orb_in%species instead.
!   dirction     -- Integer, optional: +1 -> moving downstream +s direciton, -1 -> moving upstream.
!                     0 -> Ignore. Default is to not change orb%direction except for photons which get set
!                     according to orb%vec(6).
!   E_photon     -- real(rp), optional: Photon energy if particle is a photon. Ignored otherwise.
!   t_ref_offset -- real(rp), optional: Offset of the reference time. This is non-zero when
!                     there are multiple bunches and the reference time for a particular particle
!                     is pegged to the time of the center of the bunch.
!   shift_vec6   -- Logical, optional: If present and False, prevent the shift of orb%vec(6).
!
! Output:
!   orb -- Coord_struct: Initialized coordinate.
!                 Note: For photons, orb%vec(6) is computed as sqrt(1 - vec(2)^2 - vec(4)^2) if needed.
!-

interface init_coord
  module procedure init_coord1
  module procedure init_coord2
end interface

private init_coord1, init_coord2

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine init_coord1 (orb, vec, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)
! 
! Subroutine to initialize a coord_struct. 
! This subroutine is overloaded by init_coord. See init_coord for more details.
!-

subroutine init_coord1 (orb, vec, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)

implicit none

type (coord_struct) orb, orb_temp
type (ele_struct), optional :: ele
real(rp), optional :: vec(:), t_ref_offset, E_photon
integer, optional :: element_end, particle, direction
logical, optional :: shift_vec6

!

orb_temp = coord_struct()
if (present(vec)) orb_temp%vec = vec

call init_coord2 (orb, orb_temp, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)


end subroutine init_coord1

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine init_coord2 (orb, orb_in, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)
! 
! Subroutine to initialize a coord_struct. 
! This subroutine is overloaded by init_coord. See init_coord for more details.
!-

subroutine init_coord2 (orb, orb_in, ele, element_end, particle, direction, E_photon, t_ref_offset, shift_vec6)

implicit none

type (coord_struct) orb, orb_in, orb_in_save
type (ele_struct), optional, target :: ele

real(rp), optional :: E_photon, t_ref_offset
real(rp) p0c, e_tot, ref_time

integer, optional :: element_end, particle, direction
integer species, dir

logical, optional :: shift_vec6

character(16), parameter :: r_name = 'init_coord1'

! Use temporary orb_in_save so if actual arg for vec, particle, or E_photon
! is part of the orb actual arg things do not get overwriten.

orb_in_save = orb_in  ! Needed if actual args orb and orb_in are the same.
orb = orb_in

species = orb_in_save%species
if (present(particle)) then
  if (particle /= not_set$) species = particle
endif

if (present(particle)) orb%species = particle

if (orb%species == not_set$ .and. present(ele) .and. associated (ele%branch)) then
  orb%species = default_tracking_species(ele%branch%param)
endif

if (orb%species == not_set$) then
  call out_io (s_warn$, r_name, 'NO PARTICLE SPECIES GIVEN. USING POSITRONS AS DEFAULT!')
  orb%species = positron$
endif

orb%state = alive$

dir = integer_option(0, direction)
if (dir == 0) then
  if (orb%species == photon$ .and. orb%vec(6) > 0) orb%direction = 1
  if (orb%species == photon$ .and. orb%vec(6) < 0) orb%direction = -1
else
  orb%direction = dir
  if (orb%species == photon$) orb%vec(6) = orb%direction * abs(orb%vec(6))
endif

! Set location and species

if (present(element_end)) orb%location = element_end

if (orb%location == start_end$) then
  if (orb%direction == 1) then
    orb%location = upstream_end$
  else
    orb%location = downstream_end$
  endif
endif

! Energy values

if (present(ele)) then
  if (.not. present(element_end)) then
    call out_io (s_fatal$, r_name, 'Rule: "element_end" argument must be present if "ele" argument is.')
    call err_exit
  endif
  if (orb%location /= upstream_end$ .or. ele%key == beginning_ele$) then
    p0c = ele%value(p0c$)
    e_tot = ele%value(e_tot$)
    ref_time = ele%ref_time
    if (orb%location == downstream_end$) orb%s = ele%s
  else
    p0c = ele%value(p0c_start$)
    e_tot = ele%value(e_tot_start$)
    ref_time = ele%value(ref_time_start$)
    orb%s = ele%s - ele%value(l$)
  endif
endif

! Photon

if (orb%species == photon$) then

  if (present(ele)) then
    if (present(ele)) orb%p0c = p0c
    if (ele%key == photon_init$) then
      call init_a_photon_from_a_photon_init_ele (ele, ele%branch%param, orb)
    endif
  endif

  orb%path_len = 0
  orb%beta = 1

  if (present(E_photon)) then
    if (E_photon /= 0) orb%p0c = E_photon
  endif

  ! If original particle is not a photon, photon is launched in same direciton as particle 
  if (orb_in_save%species /= photon$ .and. orb_in_save%species /= not_set$) then
    orb%vec(2:4:2) = orb%vec(2:4:2) / (1 + orb%vec(6))
    if (dir == 0) orb%direction = orb_in_save%direction
  endif
  orb%vec(6) = orb%direction * sqrt(1 - orb%vec(2)**2 - orb%vec(4)**2)

  if (orb%location == downstream_end$) then
    orb%vec(5) = ele%value(l$)
  else
    orb%vec(5) = 0
  endif

else
  orb%spin = orb%spin

endif

! If ele is present...

orb%ix_ele = -1

if (present(ele)) then

  orb%ix_ele = ele%ix_ele
  if (ele%slave_status == slice_slave$ .and. associated(ele%lord)) orb%ix_ele = ele%lord%ix_ele

  if (ele%key == beginning_ele$) orb%location = downstream_end$

  if (orb%species /= photon$) then

    orb%p0c = p0c

    ! E_gun shift. Only time p0c_start /= p0c for an init_ele is when there is an e_gun present in the branch.
    if (logic_option(.true., shift_vec6)) then
      if (ele%key == beginning_ele$) then
        orb%vec(6) = orb%vec(6) + (ele%value(p0c_start$) - ele%value(p0c$)) / ele%value(p0c$)
      elseif (ele%key == e_gun$ .or. (ele%key == marker$ .and. ele%value(e_tot_ref_init$) /= 0)) then
        orb%vec(6) = orb%vec(6) + (ele%value(p0c_ref_init$) - ele%value(p0c$)) / ele%value(p0c$)
      endif
    endif

    if (orb%vec(6) == 0) then
      orb%beta = p0c / e_tot
    else
      call convert_pc_to (p0c * (1 + orb%vec(6)), orb%species, beta = orb%beta)
    endif

    ! Do not set %t if %beta = 0 since %t may be a good value.

    if (orb%beta == 0) then
      if (orb%vec(5) /= 0) then
        call out_io (s_error$, r_name, 'Z-POSITION IS NONZERO WITH BETA = 0.', &
                                       'THIS IS NONSENSE SO SETTING Z TO ZERO.')
        orb%vec(5) = 0
      endif

    else
      orb%t = ref_time - orb%vec(5) / (orb%beta * c_light)
      if (present(t_ref_offset)) orb%t = orb%t + t_ref_offset
    endif
  endif

endif

end subroutine init_coord2

end module
