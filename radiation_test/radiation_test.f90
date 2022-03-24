program radiation_test

use bmad
use ptc_map_with_radiation_mod
use emit_6d_mod

implicit none

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (ele_struct), pointer :: ele
type (coord_struct) orb_start, orb_end
type (coord_struct), allocatable :: orbit(:)
type (normal_modes_struct) mode
type (rad_int_all_ele_struct), target :: ri_cache, ri_no_cache
type (rad_int1_struct), pointer :: rie1(:), rie2(:), rie3(:), rie4(:)
type (ptc_rad_map_struct) rad_map

real(rp) vec6(6), damp_mat(6,6), stoc_mat(6,6), unit_mat(6,6), nodamp_mat(6,6), m(6,6)
integer i, j, n, ib, ix_cache

!

open (1, file = 'output.now', recl = 200)

!

call bmad_parser('sigma.bmad', lat)
call damping_and_stochastic_rad_mats(lat%ele(0), lat%ele(1), damp_mat, stoc_mat, nodamp_mat)
call lat_to_ptc_layout(lat)
call ptc_setup_map_with_radiation(rad_map, lat%ele(0), lat%ele(1), 1, .true.)
call init_coord(orb_start, orb_start%vec, lat%ele(0), upstream_end$)
orb_start%vec(6) = 0.01_rp
call ptc_track_map_with_radiation (orb_start, rad_map, .true., .false.)
call mat_make_unit(unit_mat)

call mat_type (nodamp_mat, 0, 'bmad_nodamp_mat ' // real_str(mat_symp_error(nodamp_mat), 4))
call mat_type (rad_map%nodamp_mat, 0, 'ptc_nodamp_mat ' // real_str(mat_symp_error(rad_map%nodamp_mat), 4))
print *, '!------------------------------'
call mat_type (damp_mat, 0, 'bmad_damp_mat', '3x, 6es12.4')
call mat_type (matmul(rad_map%damp_mat,rad_map%nodamp_mat) - nodamp_mat, 0, 'ptc_damp_mat', '3x, 6es12.4')
print *, '!------------------------------'
m = damp_mat + nodamp_mat
call mat_type (matmul(matmul(transpose(m), stoc_mat), m), 0, 'bmad_stoc_var_mat (ref beginning)', '3x, 6es12.4')
print *, '!------------------------------'
call mat_type (stoc_mat, 0, 'bmad_stoc_var_mat', '3x, 6es12.4')
call mat_type (matmul(rad_map%stoc_mat,transpose(rad_map%stoc_mat)), 0, 'ptc_stoc_var_mat', '3x, 6es12.4')

!

bmad_com%radiation_damping_on = .false.
call bmad_parser('radiation_test.bmad', lat)

branch => lat%branch(1)
call reallocate_coord(orbit, branch%n_ele_max)
vec6 = 0
do i = 0, branch%n_ele_max
  call init_coord(orbit(i), vec6, branch%ele(i), upstream_end$)
enddo

call twiss_propagate_all(lat, 1)
call twiss_propagate_all(lat, 2)

ix_cache = 0
call radiation_integrals (lat, orbit, mode, ix_cache, 1, ri_cache)
call radiation_integrals (lat, orbit, mode, -2, 1, ri_no_cache)

ix_cache = 0
call radiation_integrals (lat, orbit, mode, ix_cache, 2, ri_cache)
call radiation_integrals (lat, orbit, mode, -2, 2, ri_no_cache)

rie1 => ri_cache%branch(1)%ele
rie2 => ri_no_cache%branch(1)%ele
rie3 => ri_cache%branch(2)%ele
rie4 => ri_no_cache%branch(2)%ele

do i = 1, branch%n_ele_max
  write (1, '(a, 4es14.6)') '"i0-' // int_str(i) // '" REL 1E-6', rie1(i)%i0, rie2(i)%i0, rie3(i)%i0, rie4(i)%i0
  write (1, '(a, 4es14.6)') '"i1-' // int_str(i) // '" REL 1E-6', rie1(i)%i1, rie2(i)%i1, rie3(i)%i1, rie4(i)%i1
  write (1, '(a, 4es14.6)') '"i2-' // int_str(i) // '" REL 1E-6', rie1(i)%i2, rie2(i)%i2, rie3(i)%i2, rie4(i)%i2
  write (1, '(a, 4es14.6)') '"i3-' // int_str(i) // '" REL 1E-6', rie1(i)%i3, rie2(i)%i3, rie3(i)%i3, rie4(i)%i3
  write (1, '(a, 4es14.6)') '"i4a-' // int_str(i) // '" REL 1E-6', rie1(i)%i4a, rie2(i)%i4a, rie3(i)%i4a, rie4(i)%i4a
  write (1, '(a, 4es14.6)') '"i4b-' // int_str(i) // '" REL 1E-6', rie1(i)%i4b, rie2(i)%i4b, rie3(i)%i4b, rie4(i)%i4b
  write (1, '(a, 4es14.6)') '"i5a-' // int_str(i) // '" REL 1E-6', rie1(i)%i5a, rie2(i)%i5a, rie3(i)%i5a, rie4(i)%i5a
  write (1, '(a, 4es14.6)') '"i5b-' // int_str(i) // '" REL 1E-6', rie1(i)%i5b, rie2(i)%i5b, rie3(i)%i5b, rie4(i)%i5b
  write (1, *)
enddo

!

ele => lat%ele(1)

call init_coord (orb_start, lat%particle_start, ele, upstream_end$)

call track1 (orb_start, ele, lat%param, orb_end)
write (1, '(a, 7es16.8)') '"No-Rad"   ABS 1e-16', orb_end%vec

bmad_com%radiation_damping_on = .true.
call track1 (orb_start, ele, lat%param, orb_end)
write (1, '(a, 7es16.8)') '"Rad-Damp" ABS 1e-16', orb_end%vec

bmad_com%radiation_zero_average = .true.
call track1 (orb_start, ele, lat%param, orb_end)
write (1, '(a, 7es16.8)') '"Rad-Zero" ABS 1e-16', orb_end%vec

close(1)

end program
