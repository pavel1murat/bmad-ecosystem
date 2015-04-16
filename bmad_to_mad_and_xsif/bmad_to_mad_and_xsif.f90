!+
! Program to convert a Bmad file to an XSIF file and a MAD file
!
! Usage:
!   bmad_to_mad_and_xsif {-nobpm} <bmad_file_name>
!
! The MAD and XSIF files will be created in the current directory.
!
! The bmad_file_name will have a '.bmad' appended to the name if there
! is no '.' in the original name.
!
! The XSIF file name will be the bmad_file_name with the '.bmad' suffix
! (or whatever suffix is there) replaced by a '.xsif' suffix.
!
! The MAD file name will be the bmad_file_name with the '.bmad' suffix
! (or whatever suffix is there) replaced by a '.mad' suffix.
!
! Lattices with and without bpm markers can be generated by using the 
! optional "-nobpm" command line argument. This is useful for cesr lattices where
! bpms within a quad will produce drifts with negative lengths.
! 
!-

program bmad_to_mad_and_xsif

use bmad
use write_lat_file_mod

implicit none

type (lat_struct) lat
type (coord_struct), allocatable :: orbit(:)

integer i, n_arg, ix
character(120) file_name, out_name, dir
character(16) bpm_ans
logical is_rel, nobpm

!

n_arg = cesr_iargc()
nobpm = .false.

if (n_arg == 0) then
  write (*, '(a)', advance = 'NO') 'Create lattices with and without bpm markers? (default = n) : '
  read (*, '(a)') bpm_ans
  write (*, '(a)', advance = 'NO') 'Bmad file name: '
  read (*, '(a)') file_name
  call string_trim (bpm_ans, bpm_ans, ix)
  call str_upcase (bpm_ans, bpm_ans)
  if (ix /= 0) then
    if (index('YES', bpm_ans(1:ix)) == 1) then
      nobpm = .true.
    else if (index('NO', bpm_ans(1:ix)) == 1) then
      print *, 'I do not understand this: ', trim(bpm_ans)
      stop
    endif
  endif

else

  call cesr_getarg (1, file_name)
  if (file_name == '-nobpm') then
    nobpm = .true.
    call cesr_getarg (2, file_name)
  elseif (file_name(1:1) == '-') then
    print *, 'Bad switch: ', trim(file_name)
    stop
  endif

  if ((nobpm .and. n_arg > 2) .or. (.not. nobpm .and. n_arg > 1)) then
    print *, 'Usage: bmad_to_mad_and_xsif {-nobpm} <bmad_file_name>'
    stop
  endif

endif

! Get the lattice

call file_suffixer (file_name, file_name, 'bmad', .false.)
call bmad_parser (file_name, lat)
call twiss_and_track (lat, orbit)

ix = splitfilename (file_name, dir, file_name, is_rel)

! Lattices with bpm markers

out_name = file_name
if (nobpm) then
  ix = index(out_name, '.')
  out_name = out_name(1:ix-1) // '_with_bpm'
endif

call file_suffixer (out_name, out_name, 'xsif', .true.)
call write_lattice_in_foreign_format ('XSIF', out_name, lat, orbit)

call file_suffixer (out_name, out_name, 'mad8', .true.)
call write_lattice_in_foreign_format ('MAD-8', out_name, lat, orbit)

call file_suffixer (out_name, out_name, 'madx', .true.)
call write_lattice_in_foreign_format ('MAD-X', out_name, lat, orbit)

! Lattices without bpm markers.
! Also combine drifts to either side of a detector.

if (.not. nobpm) stop

do i = 1, lat%n_ele_track
  if (lat%ele(i)%name(1:4) == 'DET_') then
    lat%ele(i)%key = -1 ! Mark for deletion
    if (lat%ele(i-1)%key == drift$ .and. lat%ele(i+1)%key == drift$) then
      lat%ele(i-1)%value(l$) = lat%ele(i-1)%value(l$) + lat%ele(i+1)%value(l$)
      lat%ele(i+1)%key = -1
    endif
  endif
enddo

call remove_eles_from_lat(lat)

out_name = file_name

call file_suffixer (out_name, out_name, 'xsif', .true.)
call write_lattice_in_foreign_format ('XSIF', out_name, lat, orbit)

call file_suffixer (out_name, out_name, 'mad8', .true.)
call write_lattice_in_foreign_format ('MAD-8', out_name, lat, orbit)

call file_suffixer (out_name, out_name, 'madx', .true.)
call write_lattice_in_foreign_format ('MAD-X', out_name, lat, orbit)

end program
