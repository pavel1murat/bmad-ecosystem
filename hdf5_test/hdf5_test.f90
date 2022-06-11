program hdf5_test

use beam_mod

implicit none

type (lat_struct) lat
type (bunch_struct), target :: bunch1, bunch2
type (coord_struct), pointer :: p
type (beam_struct) beam
type (beam_init_struct) beam_init
type (ele_struct) ele
type (grid_field_struct), pointer :: gf1(:), gf0(:)

integer i, j, n_part
logical error, good1(10), good2(10), g1, g2

!

open (1, file = 'output.now', recl = 200)

!---------------------
! Beam Read/Write

beam_init%position_file = 'beam_1.dat'
n_part = 10

call bmad_parser('lat.bmad', lat)
call init_bunch_distribution(lat%ele(0), lat%param, beam_init, 0, bunch1)
beam_init%use_t_coords = .true.
beam_init%use_z_as_t = .true.
call init_bunch_distribution(lat%ele(0), lat%param, beam_init, 0, bunch2)

! Some checks that the distribution has been correctly setup

p => bunch1%particle(7)
write (1, '(a, 6es18.10)') '"Bunch1-vec"    REL 1e-10', (p%vec(i), i = 1, 6)
write (1, '(a, 6es18.10)') '"Bunch1-other"  REL 1e-10', p%s, p%t, p%charge, p%p0c, p%beta
write (1, '(a, 6es18.10)') '"Bunch1-spin"   REL 1e-10', (p%spin(i), i = 1, 3)
write (1, '(a, 6i6)')      '"Bunch1-int"    ABS ', p%state, p%direction, p%species, p%location

p => bunch2%particle(4)
write (1, '(a, 6es18.10)') '"Bunch1-vec"    REL 1e-10', (p%vec(i), i = 1, 6)
write (1, '(a, 6es18.10)') '"Bunch1-other"  REL 1e-10', p%s, p%t, p%charge, p%p0c, p%beta
write (1, '(a, 6es18.10)') '"Bunch1-spin"   REL 1e-10', (p%spin(i), i = 1, 3)
write (1, '(a, 6i6)')      '"Bunch1-int"    ABS ', p%state, p%direction, p%species, p%location

!

do i = 1, n_part
  j = i + 2
  if (j > n_part) j = j - n_part
  bunch2%particle(i) = bunch1%particle(j)
  bunch2%particle(i)%species = photon$
  bunch2%particle(i)%spin = 0
  bunch2%particle(i)%field = [i, i+1]
  bunch2%particle(i)%dt_ref = 100_rp * (i+5.0_rp)
  bunch2%particle(i)%phase = 1d-3 * [j, j-1]
  bunch2%particle(i)%beta = 1
  bunch2%particle(i)%s = j
enddo

call hdf5_write_beam ('bunch.h5', [bunch1], .false., error)
call hdf5_write_beam ('bunch.h5', [bunch2], .true., error)
call hdf5_read_beam('bunch.h5', beam, error)

do i = 1, n_part
  good1(i) = coord_is_equal(bunch1%particle(i), beam%bunch(1)%particle(i))
  good2(i) = coord_is_equal(bunch2%particle(i), beam%bunch(2)%particle(i))  
enddo

write (1, '(a, 10l1, a)') '"Bunch1" STR "', good1, '"'
write (1, '(a, 10l1, a)') '"Bunch2" STR "', good2, '"'

!---------------------
! Grid_Field Read/Write

ele%key = sbend$
ele%value(rho$) = 4
ele%value(l$) = 3

allocate (gf0(2))
allocate (gf0(1)%ptr, gf0(2)%ptr)
allocate (gf0(1)%ptr%pt(4,2,3), gf0(2)%ptr%pt(2,3,1))

call grid_field_set_values (gf0(1), 0, xyz$)
call grid_field_set_values (gf0(2), 1, rotationally_symmetric_rz$)

call hdf5_write_grid_field ('grid_field.h5', ele, gf0, error)
call hdf5_read_grid_field  ('grid_field.h5', ele, gf1, error)

write (1, '(a, l1, a)') '"Grid1" STR "', grid_field_is_equal (gf0(1), gf1(1)), '"'
write (1, '(a, l1, a)') '"Grid2" STR "', grid_field_is_equal (gf0(2), gf1(2)), '"'

close (1)

!-----------------------------------------
contains

function coord_is_equal(p1, p2) result (equal)

type (coord_struct) p1, p2
logical equal

equal = is_eq_rv(p1%vec, p2%vec, 'bunch vec')
equal = equal .and. is_eq_rv(p1%spin, p2%spin, 'bunch spin')
equal = equal .and. is_eq_rv(p1%field, p2%field, 'bunch field')
equal = equal .and. is_eq_rv(p1%phase, p2%phase, 'bunch phase')
equal = equal .and. is_eq_r(p1%s, p2%s, 'bunch s')
equal = equal .and. is_eq_r(p1%t, p2%t, 'bunch t')
equal = equal .and. is_eq_r(p1%charge, p2%charge, 'bunch charge')
equal = equal .and. is_eq_r(p1%dt_ref, p2%dt_ref, 'bunch dt_ref')
equal = equal .and. is_eq_r(p1%p0c, p2%p0c, 'bunch p0c')
equal = equal .and. is_eq_r(p1%beta, p2%beta, 'bunch beta')

equal = equal .and. is_eq_i(p1%ix_ele, p2%ix_ele, 'bunch ix_ele')
equal = equal .and. is_eq_i(p1%ix_branch, p2%ix_branch, 'bunch ix_branch')
equal = equal .and. is_eq_i(p1%state, p2%state, 'bunch state')
equal = equal .and. is_eq_i(p1%direction, p2%direction, 'bunch direction')
equal = equal .and. is_eq_i(p1%species, p2%species, 'bunch species')
equal = equal .and. is_eq_i(p1%location, p2%location, 'bunch location')

end function coord_is_equal

!-----------------------------------------
! contains

function is_eq_r (r1, r2, who) result (equal)
real(rp), intent(in) :: r1, r2
character(*) who
logical equal

equal = (abs(r1-r2) <= 1d-15 * (abs(r1) + abs(r2)))
if (.not. equal) print *, trim(who) // 'Not equal!'

end function is_eq_r

!-----------------------------------------
! contains

function is_eq_rv (r1, r2, who) result (equal)
real(rp), intent(in) :: r1(:), r2(:)
character(*) who
logical equal

equal = all(abs(r1-r2) <= 1d-15 * (abs(r1) + abs(r2)))
if (.not. equal) print *, trim(who) // 'Not equal!'

end function is_eq_rv

!-----------------------------------------
! contains

function is_eq_i (i1, i2, who) result (equal)
integer, intent(in) :: i1, i2
character(*) who
logical equal

equal = (i1 == i2)
if (.not. equal) print *, trim(who) // 'Not equal!'

end function is_eq_i

!-----------------------------------------
! contains

function is_eq_iv (i1, i2, who) result (equal)
integer, intent(in) :: i1(:), i2(:)
character(*) who
logical equal

equal = all(i1 == i2)
if (.not. equal) print *, trim(who) // 'Not equal!'

end function is_eq_iv

!-----------------------------------------
! contains

function is_eq_l  (l1, l2, who) result (equal)
logical, intent(in) :: l1, l2
character(*) who
logical equal

equal = (l1 .eqv. l2)
if (.not. equal) print *, trim(who) // 'Not equal!'

end function is_eq_l

!-----------------------------------------------------------------
! contains

subroutine grid_field_set_values (gf, ixg, geometry)

type (grid_field_struct), target :: gf
type (grid_field_pt1_struct), pointer :: pt(:,:,:)
integer i, j, k, ixg, geometry, base

!

pt => gf%ptr%pt

do i = 1, size(pt, 1)
do j = 1, size(pt, 2)
do k = 1, size(pt, 3)
  base = 10000*i + 1000*j + 100*k + 10*ixg 
  pt(i,j,k)%B = cmplx(base + [1, 2, 3], 0.0_rp)
  pt(i,j,k)%E = cmplx(0.0_rp, base + [4, 5, 6])
enddo
enddo
enddo

gf%geometry = geometry
gf%harmonic = ixg
gf%phi0_fieldmap = 0
gf%field_scale = ixg + 4
gf%field_type = mixed$
gf%master_parameter = ixg
gf%ele_anchor_pt = ixg + 1
gf%interpolation_order = 2*ixg + 1
gf%dr = [ixg+1, ixg+2, ixg+3]
gf%r0 = [ixg+4, ixg+5, ixg+6]
gf%curved_ref_frame = (ixg == 0)

end subroutine grid_field_set_values

!-----------------------------------------------------------------
! contains

function grid_field_is_equal (gf0, gf1) result (is_equal)

type (grid_field_struct) gf0, gf1
type (grid_field_pt1_struct), pointer :: pt0(:,:,:), pt1(:,:,:)
integer i, j, k
logical is_equal

!

is_equal = .true.

pt0 => gf0%ptr%pt
pt1 => gf1%ptr%pt

is_equal = is_equal .and. is_eq_iv(shape(pt0), shape(pt1), 'Grid_field Shape')
if (.not. is_equal) return

do i = 1, 3
  if (any(int(pt0%B(i)) /= int(pt1%B(i)))) then
    print '(a, i0, a)', 'B', i, ': Not Same' 
    is_equal = .false.
  endif
  if (any(int(pt0%E(i)) /= int(pt1%E(i)))) then
    print '(a, i0, a)', 'E', i, ': Not Same' 
    is_equal = .false.
  endif
enddo

is_equal = is_equal .and. is_eq_i(gf0%geometry, gf1%geometry, 'Grid_field geometry')
is_equal = is_equal .and. is_eq_i(gf0%harmonic, gf1%harmonic, 'Grid_field harmonic')
is_equal = is_equal .and. is_eq_r(gf0%phi0_fieldmap, gf1%phi0_fieldmap, 'Grid_field phi0_fieldmap')
is_equal = is_equal .and. is_eq_r(gf0%field_scale, gf1%field_scale, 'Grid_field field_scale')
is_equal = is_equal .and. is_eq_i(gf0%field_type, gf1%field_type, 'Grid_field field_type')
is_equal = is_equal .and. is_eq_i(gf0%master_parameter, gf1%master_parameter, 'Grid_field master_parameter')
is_equal = is_equal .and. is_eq_i(gf0%ele_anchor_pt, gf1%ele_anchor_pt, 'Grid_field ele_anchor_pt')
is_equal = is_equal .and. is_eq_i(gf0%interpolation_order, gf1%interpolation_order, 'Grid_field interpolation_order')
is_equal = is_equal .and. is_eq_rv(gf0%dr, gf1%dr, 'Grid_field dr')
is_equal = is_equal .and. is_eq_rv(gf0%r0, gf1%r0, 'Grid_field r0')
is_equal = is_equal .and. is_eq_l(gf0%curved_ref_frame, gf1%curved_ref_frame, 'Grid_field curved_ref_frame')

end function grid_field_is_equal 

end program
