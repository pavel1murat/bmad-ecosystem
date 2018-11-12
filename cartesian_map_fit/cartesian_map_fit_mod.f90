module cartesian_map_fit_mod

use bmad

type term_struct
  type (cartesian_map_term1_struct) cmt
  real(rp) kxy
end type     

type (lat_struct) lat
type (term_struct), target :: term(500)
type (cartesian_map_struct), pointer :: c_map

integer :: Nx_min, Nx_max, Ny_min, Ny_max, Nz_min, Nz_max
integer :: n_grid_pts, n_opti_grid_pts, n_term, n_data_tot, n_data_grid, n_var, n_var_per_term
integer :: n_loops, n_cycles

real(rp), allocatable :: s_x_arr(:), c_x_arr(:), s_y_arr(:), c_y_arr(:), s_z_arr(:), c_z_arr(:)
real(rp), allocatable :: Bx_fit(:,:,:), By_fit(:,:,:), Bz_fit(:,:,:), y_fit(:)
real(rp), allocatable :: Bx_in(:,:,:), By_in(:,:,:), Bz_in(:,:,:)

real(rp) :: del_grid(3), sumB_in, field_scale, length_scale
real(rp) ::	de_var_to_population_factor = 5, de_coef_step = 0, de_k_step = 0
real(rp) :: de_x0_y0_step = 0, de_phi_z_step = 0

real(rp), allocatable :: div(:,:,:), curl_x(:,:,:), curl_y(:,:,:), curl_z(:,:,:)
real(rp) div_max, div_scale_max, div_scale, r0_grid(3)
real(rp) curl_x_max, curl_x_scale_max, curl_x_scale
real(rp) curl_y_max, curl_y_scale_max, curl_y_scale
real(rp) curl_z_max, curl_z_scale_max, curl_z_scale
real(rp) B_int, B_diff, merit_coef, merit_data, dB_rms
real(rp) :: merit_tot, coef_weight
real(rp) merit_x, merit_y, merit_z, x_offset_map, y_offset_map, z_offset_map

logical :: dyda_calc = .true.
logical :: mask_x0 = .true., mask_y0 = .true., mask_phi_z = .false.
logical :: calc_fit_at_exterior_grid_points_only = .false.
logical, allocatable :: valid_field(:,:,:), opti_field(:,:,:)

character(80) :: field_file
character(16) :: optimizer = 'de'

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine read_field_table (field_file)
! 
! Routine to read in a field table. Units are: cm, Gauss.
! Look at the code for the format.
!
! Input:
!   field_file    -- character(*): Name of file.Y
!                      If file starts with the string "binary_' this is a binary file.
!-

subroutine read_field_table (field_file)

implicit none

integer :: i, j, k, ix, iy, iz, ios

real(rp) xx, yy, zz, Bx, By, Bz

character(*) :: field_file
character(80) line
character(8) :: columns(7) = (/ '1 X   ', '2 Y   ', '3 Z   ', &
                                '4 BX  ', '5 BY  ', '6 BZ  ', '0 [CM]' /)


! Binary

if (field_file(1:8) == 'binary::') then

  open (1, file = field_file(9:), status = 'old', form = 'unformatted', readonly)
  read (1) Nx_min, Nx_max
  read (1) Ny_min, Ny_max
  read (1) Nz_min, Nz_max
  read (1) del_grid
  read (1) r0_grid
  read (1) length_scale, field_scale

  allocate (Bx_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max), By_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))
  allocate (Bz_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max), valid_field(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))
  allocate (opti_field(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))

  valid_field = .false.
  do 
    read (1, iostat = ios) i, j, k, Bx_in(i,j,k), By_in(i,j,k), Bz_in(i,j,k), valid_field(i,j,k)
    if (ios /= 0) exit
  enddo

  close (1)

! ASCII

else

  open (1, file = field_file, STATUS='OLD', readonly, shared)
  read (1, '(a)') line
  read (line, *) length_scale
  read (1, '(a)') line
  read (line, *) field_scale
  read (1, '(a)') line
  read (line, *) Nx_min, Nx_max
  read (1, '(a)') line
  read (line, *) Ny_min, Ny_max
  read (1, '(a)') line
  read (line, *) Nz_min, Nz_max
  read (1, '(a)') line
  read (line, *) del_grid
  read (1, '(a)') line
  read (line, *) r0_grid

  allocate (Bx_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max), By_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))
  allocate (Bz_in(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max), valid_field(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))
  allocate (opti_field(Nx_min:Nx_max,Ny_min:Ny_max,Nz_min:Nz_max))

  do
    read (1, '(a)', iostat = ios) line
    if (line(1:1) == '!' .or. line == '') cycle
    read (line, *) xx, yy, zz, Bx, By, Bz
    if (ios /= 0) exit
    i = nint (xx/del_grid(1))
    j = nint (yy/del_grid(2))
    k = nint (zz/del_grid(3))

    if (i < Nx_min .or. i > Nx_max .or. j < Ny_min .or. j > Ny_max .or. k < Nz_min .or. k > Nz_max) then
      print *, 'COMPUTED INDEX OUT OF RANGE FOR LINE: ', trim(line)
      stop
    endif
    Bx_in(i,j,k) = Bx
    By_in(i,j,k) = By
    Bz_in(i,j,k) = Bz
    valid_field(i,j,k) = .true.
  end do

  close (1)
endif

!

del_grid = del_grid * length_scale
Bx = Bx * field_scale
By = By * field_scale
Bz = Bz * field_scale

opti_field = .false.
do ix = Nx_min, Nx_max, Nx_max-Nx_min
do iy = Ny_min, Ny_max
do iz = Nz_min, Nz_max
  opti_field(ix, iy, iz) = valid_field(ix, iy, iz)
enddo
enddo
enddo

do ix = Nx_min, Nx_max
do iy = Ny_min, Ny_max, Ny_max-Ny_min
do iz = Nz_min, Nz_max
  opti_field(ix, iy, iz) = valid_field(ix, iy, iz)
enddo
enddo
enddo

do ix = Nx_min, Nx_max
do iy = Ny_min, Ny_max
do iz = Nz_min, Nz_max, Nz_max-Nz_min
  opti_field(ix, iy, iz) = valid_field(ix, iy, iz)
enddo
enddo
enddo

n_grid_pts = (Nx_max-Nx_min+1) * (Ny_max-Ny_min+1) * (Nz_max-Nz_min+1)
n_opti_grid_pts = count(opti_field)

print *, 'Field table read: ', trim(field_file)
print *, '  Number of grid field points:       ', n_grid_pts
print *, '  Number points missing in table:    ', n_grid_pts - count(valid_field)
print *, '  Number points used in optimization:', n_opti_grid_pts

end subroutine read_field_table

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine read_cartesian_map_fit_param_file (param_file, write_curl)
!
! Routine to read in the parameters for the program
!
! Input:
!   param_file    -- character(*): Name of the parameter file.
!   write_curl    -- logical: Write computed curl of field? Should be zero.
!-

subroutine read_cartesian_map_fit_param_file (param_file, write_curl)

implicit none

type (term_struct), pointer :: tm
type (cartesian_map_term1_struct), pointer :: cm
type (coord_struct) orbit

real(rp) ave_x, ave_z, dum1

integer :: i, j, k, ix, iy, iz

logical write_curl, err_flag

! sorted_field_trimmed.txt

character(*) :: param_file

namelist / parameters / field_file, coef_weight, n_loops, n_cycles, mask_x0, mask_y0, mask_phi_z, &
                  optimizer, de_var_to_population_factor, de_coef_step, de_k_step, &
                  de_x0_y0_step, de_phi_z_step

! Read in parameters and starting fit

coef_weight = 0
open (1, file = param_file, status = 'old', readonly, shared)
read (1, nml = parameters)
close (1)

! Read in field data file

call read_field_table (field_file)
call bmad_parser (param_file, lat, .false., err_flag = err_flag)
if (err_flag) stop

if (.not. associated(lat%ele(1)%cartesian_map)) then
  print *, 'No Cartesian map found for first element in lattice: ', trim(param_file)
  stop
endif

lat%ele(1)%field_calc = fieldmap$
c_map => lat%ele(1)%cartesian_map(1)

! Offset of the cartesian map

orbit%vec = 0
call to_field_map_coords (lat%ele(1), orbit, 0.0_rp, c_map%ele_anchor_pt, c_map%r0, .false., &
                                        x_offset_map, y_offset_map, z_offset_map, dum1, dum1, err_flag)

!-------------------------------------
! get the starting point

n_term = size(c_map%ptr%term)
do i = 1, n_term
  tm => term(i)
  cm => tm%cmt
  cm = c_map%ptr%term(i)

  select case (cm%form)
  case (hyper_y$)
    if (cm%kx < 0) then
      cm%kx = -cm%kx
      if (cm%family == family_x$ .or. cm%family == family_qu$) cm%coef = -cm%coef
    endif

    if (cm%ky < 0) then
      cm%ky = -cm%ky
      if (cm%family == family_x$ .or. cm%family == family_sq$) cm%coef = -cm%coef
    endif

  case (hyper_xy$)
    if (cm%kx > 0) then
      cm%kx = -cm%kx
      if (cm%family == family_x$ .or. cm%family == family_qu$) cm%coef = -cm%coef
    endif

    if (cm%ky < 0) then
      cm%ky = -cm%ky
      if (cm%family == family_y$ .or. cm%family == family_qu$) cm%coef = -cm%coef
    endif

  case (hyper_x$)
    if (cm%kx > 0) then
      cm%kx = -cm%kx
      if (cm%family == family_y$ .or. cm%family == family_sq$) cm%coef = -cm%coef
    endif

    if (cm%ky > 0) then
      cm%ky = -cm%ky
      if (cm%family == family_y$ .or. cm%family == family_qu$) cm%coef = -cm%coef
    endif
  end select

  tm%kxy = cm%kx + cm%ky
enddo

n_var_per_term = 6  ! number of vars per term
if (mask_x0) n_var_per_term = n_var_per_term - 1
if (mask_y0) n_var_per_term = n_var_per_term - 1
if (mask_phi_z) n_var_per_term = n_var_per_term - 1

n_var = n_var_per_term * n_term
n_data_grid = 3 * (n_grid_pts - (Nx_max-Nx_min-1) * (Ny_max-Ny_min-1) * (Nz_max-Nz_min-1)) 
n_data_tot = n_data_grid + n_term

allocate(s_x_arr(Nx_min:Nx_max), c_x_arr(Nx_min:Nx_max))
allocate(s_y_arr(Ny_min:Ny_max), c_y_arr(Ny_min:Ny_max))
allocate(s_z_arr(Nz_min:Nz_max), c_z_arr(Nz_min:Nz_max))

allocate (curl_x(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max), curl_y(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max))
allocate (div(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max), curl_z(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max))

allocate (Bx_fit(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max), By_fit(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max))
allocate (Bz_fit(Nx_min:Nx_max, Ny_min:Ny_max, Nz_min:Nz_max))

! This is for seeing how well the curl of the field is zero.

If (write_curl) then
  call curl_calc (Bx_in, By_in, Bz_in)
endif

sumB_in = sum(abs(Bx_in) + abs(By_in) + abs(Bz_in), valid_field)

end subroutine read_cartesian_map_fit_param_file
               
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------

subroutine curl_calc (B_x, B_y, B_z)

implicit none

integer ix0, iy0, iz0
integer ix, iy, iz

real(rp) B_x(:,:,:), B_y(:,:,:), B_z(:,:,:)
real(rp) dx, dy, dz

div_max = 0; div_scale_max = 0
curl_x_max = 0; curl_x_scale_max = 0
curl_y_max = 0; curl_y_scale_max = 0
curl_z_max = 0; curl_z_scale_max = 0

do ix = Nx_min, Nx_max-1
do iy = Ny_min, Ny_max-1
do iz = Nz_min, Nz_max-1

  dx = (sum(B_x(ix+1,iy:iy+1,iz:iz+1)) - sum(B_x(ix,iy:iy+1,iz:iz+1)))/del_grid(1)
  dy = (sum(B_y(ix:ix+1,iy+1,iz:iz+1)) - sum(B_y(ix:ix+1,iy,iz:iz+1)))/del_grid(2)
  dz = (sum(B_z(ix:ix+1,iy:iy+1,iz+1)) - sum(B_z(ix:ix+1,iy:iy+1,iz)))/del_grid(3)

  div_scale = (abs(dx) + abs(dy) + abs(dz)) / 4
  div(ix,iy,iz) = (dx + dy + dz) / 4

  !

  dy = (sum(B_z(ix,iy+1,iz:iz+1)) - sum(B_z(ix,iy,iz:iz+1)))/del_grid(2)
  dz = (sum(B_y(ix,iy:iy+1,iz+1)) - sum(B_y(ix,iy:iy+1,iz)))/del_grid(3)

  curl_x_scale = (abs(dy) + abs(dz)) / 2
  curl_x(ix,iy,iz) = (dy - dz) / 2

  !

  dx = (sum(B_z(ix+1,iy,iz:iz+1)) - sum(B_z(ix,iy,iz:iz+1)))/del_grid(1)
  dz = (sum(B_x(ix:ix+1,iy,iz+1)) - sum(B_x(ix:ix+1,iy,iz)))/del_grid(3)

  curl_y_scale = (abs(dx) + abs(dz)) / 2
  curl_y(ix,iy,iz) = (dx - dz) / 2

  !

  dx = (sum(B_y(ix+1,iy:iy+1,iz)) - sum(B_y(ix,iy:iy+1,iz)))/del_grid(1)
  dy = (sum(B_x(ix:ix+1,iy+1,iz)) - sum(B_x(ix:ix+1,iy,iz)))/del_grid(2)

  curl_z_scale = (abs(dx) + abs(dy)) / 2
  curl_z(ix,iy,iz) = (dx - dy) / 2

  !

  div_max = max(div_max, abs(div(ix,iy,iz)))
  div_scale_max = max(div_scale_max, abs(div_scale))

  curl_x_max = max(curl_x_max, abs(curl_x(ix,iy,iz)))
  curl_x_scale_max = max(curl_x_scale_max, abs(curl_x_scale))

  curl_y_max = max(curl_y_max, abs(curl_y(ix,iy,iz)))
  curl_y_scale_max = max(curl_y_scale_max, abs(curl_y_scale))

  curl_z_max = max(curl_z_max, abs(curl_z(ix,iy,iz)))
  curl_z_scale_max = max(curl_z_scale_max, abs(curl_z_scale))

enddo
enddo
enddo

end subroutine curl_calc

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------

subroutine print_stuff

implicit none

call db_rms_calc

print *, 'Nx_min, Nx_max:', Nx_min, Nx_max
print *, 'Ny_min, Ny_max:', Ny_min, Ny_max
print *, 'Nz_min, Nz_max:', Nz_min, Nz_max
print *, 'N_term:', n_term
print *, 'Chi2:     ', merit_tot
print *, 'Chi2_coef:', merit_coef
print *, 'B_diff (G):', B_diff / (3 * n_opti_grid_pts)
print *, 'dB_rms (G):', dB_rms
print *, 'B_Merit   :', B_diff / sumB_in
print *, 'B_int:  ', B_int
print '(a, 4f10.2)', ' B_diff [x, y, z, tot]:', &
                  sum(abs(Bx_fit(:,:,:)-Bx_in(:,:,:)))/n_grid_pts, &
                  sum(abs(By_fit(:,:,:)-By_in(:,:,:)))/n_grid_pts, &
                  sum(abs(Bz_fit(:,:,:)-Bz_in(:,:,:)))/n_grid_pts, &
                  B_diff/n_grid_pts
print '(a, 4f10.2)', ' B_rms [x, y, z, tot]: ', &
                  sqrt(merit_x/n_opti_grid_pts), sqrt(merit_y/n_opti_grid_pts), &
                  sqrt(merit_z/n_opti_grid_pts), dB_rms
print '(a, 4f10.2)', ' B_dat [x, y, z, tot]: ', &
                  sum(abs(Bx_in(:,:,:)))/n_grid_pts, &
                  sum(abs(By_in(:,:,:)))/n_grid_pts, &
                  sum(abs(Bz_in(:,:,:)))/n_grid_pts, &
                  sumB_in/n_grid_pts

end subroutine  

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------

subroutine db_rms_calc

db_rms = sqrt(merit_data/n_grid_pts) 

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------

subroutine funcs_lm (a, yfit, dyda, status)

implicit none

type (cartesian_map_term1_struct), pointer :: cmt
type (term_struct), pointer :: tt

real(rp), intent(in) :: a(:)
real(rp), intent(out) :: yfit(:)
real(rp), intent(out) :: dyda(:, :)
real(rp) x_pos, y_pos, z_pos, rrx, rry, rrz, dkx_dkxy, dky_dkxy
real(rp) drrx_dkx, drrx_dky, drrx_dkz, drry_dkx, drry_dky, drry_dkz, drrz_dkx, drrz_dky, drrz_dkz
real(rp) x, y, z

integer sgn_x, sgn_y, sgn_z, dsgn_x, dsgn_y, dsgn_z
integer status
integer ix, iy, iz, i, j, j_term, jj, jb

logical err_flag

! Compute the fit

Bx_fit = 0
By_fit = 0
Bz_fit = 0

jj = 0
j_term = 0

do i = 1, n_term
  tt => term(i)
  cmt => tt%cmt
  jj = j_term

  jj = jj + 1
  cmt%coef = a(jj)

  jj = jj + 1
  tt%kxy = a(jj)

  jj = jj + 1
  cmt%kz = a(jj)

  if (.not. mask_x0) then
    jj = jj + 1
    cmt%x0 = a(jj)
  endif

  if (.not. mask_y0) then
    jj = jj + 1
    cmt%y0 = a(jj)
  endif

  if (.not. mask_phi_z) then
    jj = jj + 1
    cmt%phi_z = a(jj)
  endif

  if (abs(cmt%kx) > 1000 .or. abs(cmt%ky) > 1000 .or. abs(cmt%kz) > 1000) then
    print *, 'FUNCS_LM: |K| is > 1000', i, cmt%kx, cmt%ky, cmt%kz
    merit_tot = 1e100_rp
    status = 1
    return
  endif

  ! This is the datum representing the term coefficient.

  yfit(n_data_grid+i) = cmt%coef
  if (dyda_calc) then
    dyda (n_data_grid+i, :) = 0
    dyda (n_data_grid+1, j_term+1) = 1
  endif

  ! The forms are constructed to make the field a continuous function of (kx, ky, kz) when going
  ! between hyper_y and hyper_xy and between hyper_xy and hyper_x. Note that the field is *not*
  ! continuous between hyper_y and hyper_x.

  if (tt%kxy > abs(cmt%kz)) then
    cmt%form = hyper_y$
    cmt%ky = (tt%kxy**2 + cmt%kz**2) / (2 * tt%kxy)
    cmt%kx = sqrt(cmt%ky**2 - cmt%kz**2)
  elseif (tt%kxy < -abs(cmt%kz)) then
    cmt%form = hyper_x$
    cmt%kx = (tt%kxy**2 + cmt%kz**2) / (2 * tt%kxy)
    cmt%ky = -sqrt(cmt%kx**2 - cmt%kz**2)
  else
    cmt%form = hyper_xy$
    cmt%kx = (tt%kxy - sqrt(2 * cmt%kz**2 - tt%kxy**2)) / 2
    cmt%ky = sqrt(cmt%kz**2 - cmt%kx**2)
  endif

  ! 

  do iz = Nz_min, Nz_max
    z = cmt%kz * (del_grid(3) * iz + z_offset_map - r0_grid(3)) + cmt%phi_z 
    s_z_arr(iz) = sin(z)
    c_z_arr(iz) = cos(z)
  enddo

  sgn_x = 1; sgn_y = 1; sgn_z = 1

  select case (cmt%form)
  case (hyper_y$)
    do ix = Nx_min, Nx_max
      x = cmt%kx * (del_grid(1) * ix + cmt%x0 + x_offset_map - r0_grid(1))
      s_x_arr(ix) = sin(x)
      c_x_arr(ix) = cos(x)
    enddo
    do iy = Ny_min, Ny_max
      y = cmt%ky * (del_grid(2) * iy + cmt%y0 + y_offset_map - r0_grid(2))
      s_y_arr(iy) = sinh (y)
      c_y_arr(iy) = cosh (y)
    enddo

    select case (cmt%family)
    case (family_x$);  sgn_z = -1
    case (family_y$);  sgn_x = -1; sgn_z = -1
    case (family_qu$); sgn_z = -1
    case (family_sq$); sgn_x = -1; sgn_z = -1
    end select

    rrx = cmt%kx / cmt%ky
    rry = 1
    rrz = cmt%kz / cmt%ky
    drrx_dkx = 1 / cmt%ky; drrx_dky = -rrx / cmt%ky; drrx_dkz = 0
    drry_dkx = 0; drry_dky = 0; drry_dkz = 0
    drrz_dkx = 0; drrz_dky = -rrz / cmt%ky; drrz_dkz = 1 / cmt%ky

    dkx_dkxy = (tt%kxy**2 + cmt%kz**2) / (2 * tt%kxy**2);  dky_dkxy = (tt%kxy**2 - cmt%kz**2) / (2 * tt%kxy**2)
    dsgn_x = -1; dsgn_y = 1; dsgn_z = -1

  case (hyper_xy$)
    do ix = Nx_min, Nx_max
      x = cmt%kx * (del_grid(1) * ix + cmt%x0 + x_offset_map - r0_grid(1))
      s_x_arr(ix) =  sinh(x)
      c_x_arr(ix) =  cosh(x)
    enddo
    do iy = Ny_min, Ny_max
      y = cmt%ky * (del_grid(2) * iy + cmt%y0 + y_offset_map - r0_grid(2))
      s_y_arr(iy) = sinh (y)
      c_y_arr(iy) = cosh (y)
    enddo

    select case (cmt%family)
    case (family_x$);  sgn_z = -1
    case (family_y$);  sgn_z = -1
    case (family_qu$); sgn_z = -1
    case (family_sq$); sgn_z = -1
    end select

    rrx = cmt%kx / cmt%kz
    rry = cmt%ky / cmt%kz
    rrz = 1
    drrx_dkx = 1 / cmt%kz; drrx_dky = 0; drrx_dkz = -rrx / cmt%kz
    drry_dkx = 0; drry_dky = 1 / cmt%kz; drry_dkz = -rry / cmt%kz
    drrz_dkx = 0; drrz_dky = 0; drrz_dkz = 0

    dkx_dkxy = (1 + tt%kxy / (tt%kxy - 2 * cmt%kx)) / 2;  dky_dkxy = (1 - tt%kxy / (tt%kxy - 2 * cmt%kx)) / 2
    dsgn_x = 1; dsgn_y = 1; dsgn_z = -1

  case (hyper_x$)
    do ix = Nx_min, Nx_max
      x = cmt%kx * (del_grid(1) * ix + cmt%x0 + x_offset_map - r0_grid(1))
      s_x_arr(ix) = sinh(x)
      c_x_arr(ix) = cosh(x)
    enddo
    do iy = Ny_min, Ny_max
      y = cmt%ky * (del_grid(2) * iy + cmt%y0 + y_offset_map - r0_grid(2))
      s_y_arr(iy) = sin(y)
      c_y_arr(iy) = cos(y)
    enddo

    select case (cmt%family)
    case (family_x$);  sgn_y = -1; sgn_z = -1
    case (family_y$);  sgn_z = -1
    case (family_qu$); sgn_z = -1
    case (family_sq$); sgn_x = -1
    end select

    rrx = 1
    rry = cmt%ky / cmt%kx
    rrz = cmt%kz / cmt%kx
    drrx_dkx = 0; drrx_dky = 0; drrx_dkz = 0
    drry_dkx = -rry / cmt%kx; drry_dky = 1 / cmt%kx; drry_dkz = 0
    drrz_dkx = -rrz / cmt%kx; drrz_dky = 0; drrz_dkz = 1 / cmt%kx

    dkx_dkxy = (tt%kxy**2 - cmt%kz**2) / (2 * tt%kxy**2);  dky_dkxy = (tt%kxy**2 + cmt%kz**2) / (2 * tt%kxy**2)
    dsgn_x = 1; dsgn_y = -1; dsgn_z = -1
  end select

  !

  Bx_fit = 0
  By_fit = 0
  Bz_fit = 0
  jb = 0

  if (calc_fit_at_exterior_grid_points_only) then
    do ix = Nx_min, Nx_max, Nx_max-Nx_min
    do iy = Ny_min, Ny_max
    do iz = Nz_min, Nz_max
      call add_to_field(jb)
    enddo
    enddo
    enddo

    do ix = Nx_min, Nx_max
    do iy = Ny_min, Ny_max, Ny_max-Ny_min
    do iz = Nz_min, Nz_max
      call add_to_field(jb)
    enddo
    enddo
    enddo

    do ix = Nx_min, Nx_max
    do iy = Ny_min, Ny_max
    do iz = Nz_min, Nz_max, Nz_max-Nz_min
      call add_to_field(jb)
    enddo
    enddo
    enddo

  else ! Optimizer not runnging
    do ix = Nx_min, Nx_max
    do iy = Ny_min, Ny_max
    do iz = Nz_min, Nz_max
      call add_to_field(jb)
    enddo
    enddo
    enddo
  endif

  j_term = jj

enddo

!

dB_rms = 0
B_diff = 0
merit_x = 0
merit_y = 0
merit_z = 0

if (calc_fit_at_exterior_grid_points_only) then
  do ix = Nx_min, Nx_max, Nx_max-Nx_min
  do iy = Ny_min, Ny_max
  do iz = Nz_min, Nz_max
    jj = jj + 1
    yfit(jj) = Bx_fit(ix,iy,iz) - Bx_in(ix,iy,iz)
    merit_x = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = By_fit(ix,iy,iz) - By_in(ix,iy,iz)
    merit_y = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = Bz_fit(ix,iy,iz) - Bz_in(ix,iy,iz)
    merit_z = merit_x + yfit(jj)**2
  enddo
  enddo
  enddo

  do ix = Nx_min, Nx_max
  do iy = Ny_min, Ny_max, Ny_max-Ny_min
  do iz = Nz_min, Nz_max
    jj = jj + 1
    yfit(jj) = Bx_fit(ix,iy,iz) - Bx_in(ix,iy,iz)
    merit_x = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = By_fit(ix,iy,iz) - By_in(ix,iy,iz)
    merit_y = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = Bz_fit(ix,iy,iz) - Bz_in(ix,iy,iz)
    merit_z = merit_x + yfit(jj)**2
  enddo
  enddo
  enddo

  do ix = Nx_min, Nx_max
  do iy = Ny_min, Ny_max
  do iz = Nz_min, Nz_max, Nz_max-Nz_min
    jj = jj + 1
    yfit(jj) = Bx_fit(ix,iy,iz) - Bx_in(ix,iy,iz)
    merit_x = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = By_fit(ix,iy,iz) - By_in(ix,iy,iz)
    merit_y = merit_x + yfit(jj)**2
    jj = jj + 1
    yfit(jj) = Bz_fit(ix,iy,iz) - Bz_in(ix,iy,iz)
    merit_z = merit_x + yfit(jj)**2
  enddo
  enddo
  enddo

  return
endif

!

merit_coef = sum(abs((term(1:n_term)%cmt%coef))) * coef_weight
merit_data = merit_x + merit_y + merit_z
merit_tot = merit_data + merit_coef

!---------------------------------------------
contains

subroutine add_to_field(jb)

real(rp) s_x, c_x, s_y, c_y, s_z, c_z
integer iv, jb, jb0

!

jb0 = jb
jb = jb + 3

x_pos = del_grid(1) * ix + cmt%x0 + x_offset_map - r0_grid(1)
y_pos = del_grid(2) * iy + cmt%y0 + y_offset_map - r0_grid(2)
z_pos = del_grid(3) * iz          + z_offset_map - r0_grid(3)

s_x = s_x_arr(ix)
c_x = c_x_arr(ix)
s_y = s_y_arr(iy)
c_y = c_y_arr(iy)
s_z = s_z_arr(iz)
c_z = c_z_arr(iz)

!---

select case (cmt%family)
case (family_x$)
  Bx_fit(ix,iy,iz) = Bx_fit(ix,iy,iz) + cmt%coef * rrx * c_x * c_y * c_z * sgn_x
  By_fit(ix,iy,iz) = By_fit(ix,iy,iz) + cmt%coef * rry * s_x * s_y * c_z * sgn_y
  Bz_fit(ix,iy,iz) = Bz_fit(ix,iy,iz) + cmt%coef * rrz * s_x * c_y * s_z * sgn_z
  if (.not. dyda_calc) return
  ! dB_fit/dCoef terms
  dyda(jb0+1,j_term+1) = rrx * c_x * c_y * c_z * sgn_x   
  dyda(jb0+2,j_term+1) = rry * s_x * s_y * c_z * sgn_y
  dyda(jb0+3,j_term+1) = rrz * s_x * c_y * s_z * sgn_z
  ! dB_fit/dkxy terms
  dyda(jb0+1,j_term+2) = cmt%coef * c_y * c_z * sgn_x * (drrx_dkx * c_x + rrx * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * c_z * sgn_x * (drrx_dky * c_y + rrx * s_y * y_pos * dsgn_y) * dky_dkxy
  dyda(jb0+2,j_term+2) = cmt%coef * s_y * c_z * sgn_y * (drry_dkx * s_x + rry * c_x * x_pos) * dkx_dkxy + &
                        cmt%coef * s_x * c_z * sgn_y * (drry_dky * s_y + rry * c_y * y_pos) * dky_dkxy
  dyda(jb0+3,j_term+2) = cmt%coef * c_y * s_z * sgn_z * (drrz_dkx * s_x + rrz * c_x * x_pos) * dkx_dkxy + &
                        cmt%coef * s_x * s_z * sgn_z * (drrz_dky * c_y + rrz * s_y * y_pos * dsgn_y) * dky_dkxy
  ! dB_fit/dkz terms
  dyda(jb0+1,j_term+3) = cmt%coef * c_x * c_y * sgn_x * (drrx_dkz * c_z + rrx * s_z * z_pos * dsgn_z)
  dyda(jb0+2,j_term+3) = cmt%coef * s_x * s_y * sgn_y * (drry_dkz * c_z + rry * s_z * z_pos * dsgn_z)
  dyda(jb0+3,j_term+3) = cmt%coef * s_x * c_y * sgn_z * (drrz_dkz * s_z + rrz * c_z * z_pos)

  iv = j_term+3
  if (.not. mask_x0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * c_y * c_z * sgn_x * cmt%kx * dsgn_x
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * s_y * c_z * sgn_y * cmt%kx 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * c_y * s_z * sgn_z * cmt%kx 
  endif

  if (.not. mask_y0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * s_y * c_z * sgn_x * cmt%ky * dsgn_y
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * c_y * c_z * sgn_y * cmt%ky 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * s_y * s_z * sgn_z * cmt%ky * dsgn_y
  endif

  if (.not. mask_phi_z) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * c_y * s_z * sgn_x * dsgn_z
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * s_y * s_z * sgn_y * dsgn_z 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * c_y * c_z * sgn_z
  endif

case (family_y$)
  Bx_fit(ix,iy,iz) = Bx_fit(ix,iy,iz) + cmt%coef * rrx * s_x * s_y * c_z * sgn_x
  By_fit(ix,iy,iz) = By_fit(ix,iy,iz) + cmt%coef * rry * c_x * c_y * c_z * sgn_y
  Bz_fit(ix,iy,iz) = Bz_fit(ix,iy,iz) + cmt%coef * rrz * c_x * s_y * s_z * sgn_z
  if (.not. dyda_calc) return
  ! dB_fit/dCoef terms
  dyda(jb0+1,j_term+1) = rrx * s_x * s_y * c_z * sgn_x
  dyda(jb0+2,j_term+1) = rry * c_x * c_y * c_z * sgn_y
  dyda(jb0+3,j_term+1) = rrz * c_x * s_y * s_z * sgn_z
  ! dB_fit/dkxy terms
  dyda(jb0+1,j_term+2) = cmt%coef * s_y * c_z * sgn_x * (drrx_dkx * s_x + rrx * c_x * x_pos) * dkx_dkxy + &
                        cmt%coef * s_x * c_z * sgn_x * (drrx_dky * s_y + rrx * c_y * y_pos) * dky_dkxy
  dyda(jb0+2,j_term+2) = cmt%coef * c_y * c_z * sgn_y * (drry_dkx * c_x + rry * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * c_z * sgn_y * (drry_dky * c_y + rry * s_y * y_pos * dsgn_y) * dky_dkxy
  dyda(jb0+3,j_term+2) = cmt%coef * s_y * s_z * sgn_z * (drrz_dkx * c_x + rrz * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * s_z * sgn_z * (drrz_dky * s_y + rrz * c_y * y_pos) * dky_dkxy
  ! dB_fit/dkz terms
  dyda(jb0+1,j_term+3) = cmt%coef * s_x * s_y * sgn_x * (drrx_dkz * c_z + rrx * s_z * z_pos * dsgn_z)
  dyda(jb0+2,j_term+3) = cmt%coef * c_x * c_y * sgn_y * (drry_dkz * c_z + rry * s_z * z_pos * dsgn_z)
  dyda(jb0+3,j_term+3) = cmt%coef * c_x * s_y * sgn_z * (drrz_dkz * s_z + rrz * c_z * z_pos)

  iv = j_term+3
  if (.not. mask_x0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * s_y * c_z * sgn_x * cmt%kx
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * c_y * c_z * sgn_y * cmt%kx * dsgn_x 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * s_y * s_z * sgn_z * cmt%kx * dsgn_x
  endif

  if (.not. mask_y0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * c_y * c_z * sgn_x * cmt%ky
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * s_y * c_z * sgn_y * cmt%ky * dsgn_y 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * c_y * s_z * sgn_z * cmt%ky
  endif

  if (.not. mask_phi_z) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * s_y * s_z * sgn_x * dsgn_z
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * c_y * s_z * sgn_y * dsgn_z 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * s_y * c_z * sgn_z
  endif

!---

case (family_qu$)
  Bx_fit(ix,iy,iz) = Bx_fit(ix,iy,iz) + cmt%coef * rrx * c_x * s_y * c_z * sgn_x
  By_fit(ix,iy,iz) = By_fit(ix,iy,iz) + cmt%coef * rry * s_x * c_y * c_z * sgn_y
  Bz_fit(ix,iy,iz) = Bz_fit(ix,iy,iz) + cmt%coef * rrz * s_x * s_y * s_z * sgn_z
  if (.not. dyda_calc) return
  ! dB_fit/dCoef terms
  dyda(jb0+1,j_term+1) = rrx * c_x * s_y * c_z * sgn_x
  dyda(jb0+2,j_term+1) = rry * s_x * c_y * c_z * sgn_y
  dyda(jb0+3,j_term+1) = rrz * s_x * s_y * s_z * sgn_z
  ! dB_fit/dkxy terms
  dyda(jb0+1,j_term+2) = cmt%coef * s_y * c_z * sgn_x * (drrx_dkx * c_x + rrx * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * c_z * sgn_x * (drrx_dky * s_y + rrx * c_y * y_pos) * dky_dkxy
  dyda(jb0+2,j_term+2) = cmt%coef * c_y * c_z * sgn_y * (drry_dkx * s_x + rry * c_x * x_pos) * dkx_dkxy + &
                        cmt%coef * s_x * c_z * sgn_y * (drry_dky * c_y + rry * s_y * y_pos * dsgn_y) * dky_dkxy
  dyda(jb0+3,j_term+2) = cmt%coef * s_y * s_z * sgn_z * (drrz_dkx * s_x + rrz * c_x * x_pos) * dkx_dkxy + &
                        cmt%coef * s_x * s_z * sgn_z * (drrz_dky * s_y + rrz * c_y * y_pos) * dky_dkxy
  ! dB_fit/dkz terms
  dyda(jb0+1,j_term+3) = cmt%coef * c_x * s_y * sgn_x * (drrx_dkz * c_z + rrx * s_z * z_pos * dsgn_z)
  dyda(jb0+2,j_term+3) = cmt%coef * s_x * c_y * sgn_y * (drry_dkz * c_z + rry * s_z * z_pos * dsgn_z)
  dyda(jb0+3,j_term+3) = cmt%coef * s_x * s_y * sgn_z * (drrz_dkz * s_z + rrz * c_z * z_pos)

  iv = j_term+3
  if (.not. mask_x0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * s_y * c_z * sgn_x * cmt%kx * dsgn_x
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * c_y * c_z * sgn_y * cmt%kx 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * s_y * s_z * sgn_z * cmt%kx 
  endif

  if (.not. mask_y0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * c_y * c_z * sgn_x * cmt%ky
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * s_y * c_z * sgn_y * cmt%ky * dsgn_y 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * c_y * s_z * sgn_z * cmt%ky
  endif

  if (.not. mask_phi_z) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * s_y * s_z * sgn_x * dsgn_z
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * c_y * s_z * sgn_y * dsgn_z 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * s_y * c_z * sgn_z
  endif

!---

case (family_sq$)
  Bx_fit(ix,iy,iz) = Bx_fit(ix,iy,iz) + cmt%coef * rrx * s_x * c_y * c_z * sgn_x
  By_fit(ix,iy,iz) = By_fit(ix,iy,iz) + cmt%coef * rry * c_x * s_y * c_z * sgn_y
  Bz_fit(ix,iy,iz) = Bz_fit(ix,iy,iz) + cmt%coef * rrz * c_x * c_y * s_z * sgn_z
  if (.not. dyda_calc) return
  ! dB_fit/dCoef terms
  dyda(jb0+1,j_term+1) = rrx * s_x * c_y * c_z * sgn_x
  dyda(jb0+2,j_term+1) = rry * c_x * s_y * c_z * sgn_y
  dyda(jb0+3,j_term+1) = rrz * c_x * c_y * s_z * sgn_z
  ! dB_fit/dkxy terms
  dyda(jb0+1,j_term+2) = cmt%coef * c_y * c_z * sgn_x * (drrx_dkx * s_x + rrx * c_x * x_pos)          * dkx_dkxy + &
                        cmt%coef * s_x * c_z * sgn_x * (drrx_dky * c_y + rrx * s_y * y_pos * dsgn_y) * dky_dkxy
  dyda(jb0+2,j_term+2) = cmt%coef * s_y * c_z * sgn_y * (drry_dkx * c_x + rry * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * c_z * sgn_y * (drry_dky * s_y + rry * c_y * y_pos)          * dky_dkxy
  dyda(jb0+3,j_term+2) = cmt%coef * c_y * s_z * sgn_z * (drrz_dkx * c_x + rrz * s_x * x_pos * dsgn_x) * dkx_dkxy + &
                        cmt%coef * c_x * s_z * sgn_z * (drrz_dky * c_y + rrz * s_y * y_pos * dsgn_y) * dky_dkxy
  ! dB_fit/dkz terms
  dyda(jb0+1,j_term+3) = cmt%coef * s_x * c_y * sgn_x * (drrx_dkz * c_z + rrx * s_z * z_pos * dsgn_z)
  dyda(jb0+2,j_term+3) = cmt%coef * c_x * s_y * sgn_y * (drry_dkz * c_z + rry * s_z * z_pos * dsgn_z)
  dyda(jb0+3,j_term+3) = cmt%coef * c_x * c_y * sgn_z * (drrz_dkz * s_z + rrz * c_z * z_pos)

  iv = j_term+3
  if (.not. mask_x0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * c_x * c_y * c_z * sgn_x * cmt%kx
    dyda(jb0+2,iv) = cmt%coef * rry * s_x * s_y * c_z * sgn_y * cmt%kx * dsgn_x 
    dyda(jb0+3,iv) = cmt%coef * rrz * s_x * c_y * s_z * sgn_z * cmt%kx * dsgn_x
  endif

  if (.not. mask_y0) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * s_y * c_z * sgn_x * cmt%ky * dsgn_y
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * c_y * c_z * sgn_y * cmt%ky 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * s_y * s_z * sgn_z * cmt%ky * dsgn_y
  endif

  if (.not. mask_phi_z) then
    iv = iv + 1
    dyda(jb0+1,iv) = cmt%coef * rrx * s_x * c_y * s_z * sgn_x * dsgn_z
    dyda(jb0+2,iv) = cmt%coef * rry * c_x * s_y * s_z * sgn_y * dsgn_z 
    dyda(jb0+3,iv) = cmt%coef * rrz * c_x * c_y * c_z * sgn_z
  endif

end select

! coef derivative

end subroutine add_to_field

end subroutine funcs_lm

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------

function funcs_de (var_vec, status, iter_count) result (merit)

implicit none

real(rp) var_vec(:), merit
real(rp) dummy(1, 1)

integer status, iter_count

!

call funcs_lm (var_vec, y_fit, dummy, status)
merit = merit_tot

end function funcs_de

end module
