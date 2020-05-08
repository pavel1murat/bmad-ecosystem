!+
! Subroutine track_a_bend (orbit, ele, param, mat6, make_matrix)
!
! Bmad_standard tracking through a bend element. 
!
! Input:
!   orbit       -- Coord_struct: Starting position.
!   ele         -- Ele_struct: Bend element.
!   param       -- lat_param_struct: Lattice parameters.
!   mat6(6,6)   -- real(rp), optional: Transfer matrix up to the element.
!   make_matrix -- logical, optional: Propagate the transfer matrix? Default is false.
!
! Output:
!   orbit      -- coord_struct: End position.
!   mat6(6,6)  -- real(rp), optional: Transfer matrix to the element end.
!-

subroutine track_a_bend (orbit, ele, param, mat6, make_matrix)

use fringe_mod, except_dummy => track_a_bend

implicit none

type (coord_struct) :: orbit, start_orb
type (ele_struct), target :: ele
type (lat_param_struct) :: param
type (fringe_edge_info_struct) fringe_info

real(rp), optional :: mat6(6,6)
real(rp) mat6_i(6,6), rel_charge_dir, c_dir, g, g_tot, g_err, k_1, r_step, step_len, angle
real(rp) pz, rel_p, rel_p2, x, px, y, py, z, pt, phi_1, sin_plus, cos_plus, alpha, L_p, L_c, g_p
real(rp) sinc_a, r, rad, denom, L_v, L_u, dalpha, dx2, dL_c, dL_p, dphi_1, dpt, dg_p, angle_p
real(rp) cos_a, sin_a, dL_u, dL_v, dangle_p, beta_ref
real(rp) an(0:n_pole_maxx), bn(0:n_pole_maxx), an_elec(0:n_pole_maxx), bn_elec(0:n_pole_maxx)

integer n, n_step, ix_pole_max, ix_elec_max

logical, optional :: make_matrix

!-----------------------------------------------------------------------

start_orb = orbit

call offset_particle (ele, param, set$, orbit, set_hvkicks = .false., mat6 = mat6, make_matrix = make_matrix)

! Entrance edge kick

rel_charge_dir = ele%orientation * orbit%direction * rel_tracking_charge_to_mass(orbit, param)
c_dir = ele%orientation * orbit%direction * charge_of(orbit%species)

nullify(fringe_info%hard_ele)
fringe_info%particle_at = first_track_edge$
call apply_element_edge_kick(orbit, fringe_info, ele, param, .false., mat6, make_matrix)

! Set some parameters

g = ele%value(g$)
g_tot = (g + ele%value(g_err$)) * rel_charge_dir
g_err = g_tot - g
k_1 = ele%value(k1$) * rel_charge_dir
if (nint(ele%value(exact_multipoles$)) /= off$) then
  k_1 = 0  ! Is folded in with multipoles.
  ix_pole_max = max(1, ix_pole_max)
  call multipole_ele_to_ab(ele, .false., ix_pole_max, an, bn, magnetic$, include_kicks$)
else
  call multipole_ele_to_ab(ele, .false., ix_pole_max, an, bn, magnetic$, include_kicks_except_k1$)
endif
call multipole_ele_to_ab(ele, .false., ix_elec_max, an_elec, bn_elec, electric$)

if (.not. ele%is_on) then
  g_err = -g
  g_tot = 0
  k_1 = 0
endif

! multipole kick at the beginning.

n_step = 1
if (ix_pole_max > -1 .or. ix_elec_max > -1) n_step = max(nint(ele%value(l$) / ele%value(ds_step$)), 1)
r_step = 1.0_rp / n_step
step_len = ele%value(l$) * r_step
angle = g * step_len

if (ix_pole_max > -1 .or. ix_elec_max > -1) call apply_multipole_kicks (0.5_rp, step_len)

! And track with n_step steps

do n = 1, n_step

  pz = orbit%vec(6)
  rel_p  = 1 + pz
  rel_p2 = rel_p**2

  ! with k1 /= 0 use small angle approximation

  if (k_1 /= 0) then

    call sbend_body_with_k1_map (ele, param, n_step, orbit, mat6, make_matrix)
    orbit%vec(5) = orbit%vec(5) + low_energy_z_correction(orbit, ele, step_len, mat6, make_matrix)

  elseif ((g == 0 .and. g_err == 0) .or. step_len == 0) then
    call track_a_drift (orbit, step_len, mat6, make_matrix)

  !-----------------------------------------------------------------------
  ! Track through main body...
  ! See Bmad manual for equations.

  else
    x  = orbit%vec(1)
    px = orbit%vec(2)
    y  = orbit%vec(3)
    py = orbit%vec(4)
    z  = orbit%vec(5)

    beta_ref = ele%value(p0c$) / ele%value(E_tot$)
    sinc_a = sinc(angle)
    pt = sqrt(rel_p2 - py**2)
    g_p = g_tot / pt
    phi_1 = asin(px / pt)
    cos_a = cos(angle)
    sin_a = sin(angle)
    cos_plus = cos(angle + phi_1)
    sin_plus = sin(angle + phi_1)
    alpha = 2 * (1 + g*x) * sin_plus * step_len * sinc_a - g_p * ((1 + g*x) * step_len * sinc_a)**2
    r = cos_plus**2 + g_p*alpha
    if (r < 0) then   ! Particle does not intersect exit face.
      orbit%state = lost$
      orbit%vec(1) = 2 * bmad_com%max_aperture_limit
      return
    endif
    rad = sqrt(r)
    if (cos_a > 0) then
      denom = rad + cos_plus
      orbit%vec(1) = x * cos_a + step_len**2 * g * cosc(angle) + alpha / denom
    else
      denom = rad - cos_plus
      orbit%vec(1) = x * cos_a + step_len**2 * g * cosc(angle) + denom / g_p
    endif
    L_u = orbit%vec(1) - step_len**2 * g * cosc(angle) - x * cos_a 
    L_v = -step_len * sinc_a - x * sin_a
    L_c = sqrt(L_v**2 + L_u**2)
    angle_p = 2 * (angle + phi_1 - atan2(L_v, L_u)) - pi
    L_p = L_c / sinc(angle_p/2)
    orbit%vec(2) = pt * sin(phi_1 + angle - angle_p)
    orbit%vec(3) = y + py * L_p / pt
    orbit%vec(5) = z + orbit%beta * step_len / beta_ref - rel_p * L_p / pt 

    if (logic_option(.false., make_matrix)) then
      call mat_make_unit (mat6_i)

      dalpha = 2 * g * sin_plus * step_len * sinc_a - 2 * g_p * g * (1 + g*x) * (step_len * sinc_a)**2
      dx2 = cos_a + dalpha * (1 / (2 * rad))   ! cos_a < 0 form
      dL_u = dx2 - cos_a
      dL_v = -sin_a
      dL_c = (L_u * dL_u + L_v * dL_v)/ L_c
      dangle_p = 2 * (dL_u * L_v - dL_v * L_u) / L_c**2
      dL_p = dL_c / sinc(angle_p/2) - dangle_p * L_c * sinc(angle_p/2, 1) / (2 * sinc(angle_p/2)**2)

      mat6_i(1,1) = dx2
      mat6_i(2,1) = -dangle_p * pt * cos(phi_1 + angle - angle_p)
      mat6_i(3,1) = py * dL_p / pt
      mat6_i(5,1) = -rel_p * dL_p / pt

      dphi_1 = 1 / (pt * cos(phi_1))
      dalpha = 2 * dphi_1 * (1 + g * x) * cos_plus * step_len * sinc_a
      if (cos_a > 0) then
        dx2 = dalpha * (1 / denom - alpha * g_p / (2 * rad * denom**2)) + &
              alpha * dphi_1 * sin_plus * (cos_plus / rad + 1) / denom**2
      else
        dx2 = dalpha / (2 * rad) + dphi_1 * sin_plus * (-cos_plus / rad + 1) / g_p
      endif
      dL_u = dx2
      dL_c = (L_u * dL_u)/ L_c
      dangle_p = 2 * dphi_1 + 2 * (dL_u * L_v) / L_c**2
      dL_p = dL_c / sinc(angle_p/2) - dangle_p * L_c * sinc(angle_p/2, 1) / (2 * sinc(angle_p/2)**2)

      mat6_i(1,2) = dx2
      mat6_i(2,2) = (dphi_1 - dangle_p) * pt * cos(phi_1 + angle - angle_p)
      mat6_i(3,2) = py * dL_p / pt
      mat6_i(5,2) = -rel_p * dL_p / pt

      dpt = -py / pt
      dphi_1 = -px * dpt / (pt**2 * cos(phi_1))
      dg_p = -g_tot * dpt / pt**2
      dalpha = 2 * dphi_1 * (1 + g*x) * cos_plus * step_len * sinc_a - dg_p * ((1 + g*x) * step_len * sinc_a)**2
      if (cos_a > 0) then
        dx2 = dalpha * (1 / denom - alpha * g_p / (2 * rad * denom**2)) + &
              alpha * dphi_1 * sin_plus * (cos_plus / rad + 1) / denom**2 - &
              alpha**2 * dg_p / (2 * rad * denom**2)
      else
        dx2 = dalpha / (2 * rad) + dphi_1 * sin_plus * (-cos_plus / rad + 1) / g_p + &
              dg_p * (alpha / (2 * rad * g_p) - denom / g_p**2)
      endif
      dL_u = dx2
      dL_c = (L_u * dL_u)/ L_c
      dangle_p = 2 * dphi_1 + 2 * (dL_u * L_v) / L_c**2
      dL_p = dL_c / sinc(angle_p/2) - dangle_p * L_c * sinc(angle_p/2, 1) / (2 * sinc(angle_p/2)**2)

      mat6_i(1,4) = dx2
      mat6_i(2,4) = dpt * sin(phi_1 + angle - angle_p) + &
                    (dphi_1 - dangle_p) * pt * cos(phi_1 + angle - angle_p)
      mat6_i(3,4) = (L_p + py * dL_p) / pt - py * L_p * dpt / pt**2
      mat6_i(5,4) = -rel_p * (dL_p / pt - L_p * dpt / pt**2)

      dpt = rel_p / pt
      dphi_1 = -px * dpt / (pt**2 * cos(phi_1))
      dg_p = -g_tot * dpt / pt**2
      dalpha = 2 * dphi_1 * (1 + g*x) * cos_plus * step_len * sinc_a - dg_p * ((1 + g*x) * step_len * sinc_a)**2
      if (cos_a > 0) then
        dx2 = dalpha * (1 / denom - alpha * g_p / (2 * rad * denom**2)) + &
              alpha * dphi_1 * sin_plus * (cos_plus / rad + 1) / denom**2 - &
              alpha**2 * dg_p / (2 * rad * denom**2)
      else
        dx2 = dalpha / (2 * rad) + dphi_1 * sin_plus * (-cos_plus / rad + 1) / g_p + &
              dg_p * (alpha / (2 * rad * g_p) - denom / g_p**2)
      endif
      dL_u = dx2
      dL_c = (L_u * dL_u)/ L_c
      dangle_p = 2 * dphi_1 + 2 * (dL_u * L_v) / L_c**2
      dL_p = dL_c / sinc(angle_p/2) - dangle_p * L_c * sinc(angle_p/2, 1) / (2 * sinc(angle_p/2)**2)

      mat6_i(1,6) = dx2
      mat6_i(2,6) = dpt * sin(phi_1 + angle - angle_p) + &
                    (dphi_1 - dangle_p) * pt * cos(phi_1 + angle - angle_p)
      mat6_i(3,6) = py * dL_p / pt - py * L_p * dpt / pt**2
      mat6_i(5,6) = (1 - orbit%beta**2) * orbit%beta * step_len / (rel_p * beta_ref) - &
                      L_p / pt - rel_p * (dL_p / pt - L_p * dpt / pt**2)

      mat6 = matmul(mat6_i, mat6)
    endif

  endif

  ! multipole kick

  if (ix_pole_max > -1 .or. ix_elec_max > -1) then
    if (n == n_step) then
      call apply_multipole_kicks (0.5_rp, step_len)
    else
      call apply_multipole_kicks (1.0_rp, step_len)
    endif
  endif

enddo

! Track through the exit face. Treat as thin lens.
! Need low energy z correction except when using track_a_drift.

if (orbit_too_large(orbit, param)) return

fringe_info%particle_at = second_track_edge$
call apply_element_edge_kick(orbit, fringe_info, ele, param, .false., mat6, make_matrix)

call offset_particle (ele, param, unset$, orbit, set_hvkicks = .false., mat6 = mat6, make_matrix = make_matrix)

orbit%t = start_orb%t + ele%value(delta_ref_time$) + (start_orb%vec(5) - orbit%vec(5)) / (orbit%beta * c_light)

if (orbit%direction == 1) then
  orbit%s = ele%s
else
  orbit%s = ele%s_start
endif

!-------------------------------------------------------------------------------------------------------
contains

subroutine apply_multipole_kicks (coef, step_len)

type (em_field_struct) field
type (coord_struct) orb0

real(rp) coef, step_len
real(rp) ps, ps2, kx, ky, alpha, f_coef, df_coef_dx, kmat(6,6), rel_p0
real(rp) mc2, dk_dp, pc0, E0, E1, f, df_dps_coef, dkm(2,2), f_p0c, Ex, Ey
integer i, charge

! Calculate field

charge = charge_of(orbit%species)

if (nint(ele%value(exact_multipoles$)) /= off$ .and. ele%value(g$) /= 0) then
  call bend_exact_multipole_field (ele, param, orbit, .true., field, make_matrix)

else
  field = em_field_struct()
  f_p0c = ele%value(p0c$) / (c_light * charge_of(param%particle))

  do i = 0, ix_pole_max
    if (an(i) == 0 .and. bn(i) == 0) cycle
    if (logic_option(.false., make_matrix)) then
      call ab_multipole_kick(an(i), bn(i), i, param%particle, 0, orbit, kx, ky, dkm)
    else
      call ab_multipole_kick(an(i), bn(i), i, param%particle, 0, orbit, kx, ky)
    endif
    field%B(1) = field%B(1) + f_p0c * ky / ele%value(l$)
    field%B(2) = field%B(2) - f_p0c * kx / ele%value(l$)
    if (logic_option(.false., make_matrix)) then
      field%dB(1,1) = field%dB(1,1) + f_p0c * dkm(2,1) / ele%value(l$)
      field%dB(1,2) = field%dB(1,2) + f_p0c * dkm(2,2) / ele%value(l$)
      field%dB(2,1) = field%dB(2,1) - f_p0c * dkm(1,1) / ele%value(l$)
      field%dB(2,2) = field%dB(2,2) - f_p0c * dkm(1,2) / ele%value(l$)
    endif
  enddo

  ! Add electric multipoles

  do i = 0, ix_elec_max
    if (an_elec(i) == 0 .and. bn_elec(i) == 0) cycle
    call elec_multipole_field(an_elec(i), bn_elec(i), i, orbit, Ex, Ey, dkm, .true.)
    field%E(1) = field%E(1) + Ex
    field%E(2) = field%E(2) + Ey
    field%dE(1:2,1:2) = field%dE(1:2,1:2) + dkm
  enddo
endif

! Magnetic kick.

if (ix_pole_max > -1) then
  orb0 = orbit
  f_coef = coef * c_dir * step_len * (1 + ele%value(g$) * orbit%vec(1)) * c_light / orb0%p0c
  orbit%vec(2) = orbit%vec(2) - f_coef * field%B(2)
  orbit%vec(4) = orbit%vec(4) + f_coef * field%B(1)

  if (logic_option(.false., make_matrix)) then
    df_coef_dx = coef * c_dir * step_len * ele%value(g$) * c_light / orb0%p0c

    mat6(2,:) = mat6(2,:) - (f_coef * field%dB(2,1) + df_coef_dx * field%B(2)) * mat6(1,:) - & 
                            (f_coef * field%dB(2,2)) * mat6(3,:)
    mat6(4,:) = mat6(4,:) + (f_coef * field%dB(1,1) + df_coef_dx * field%B(1)) * mat6(1,:) + & 
                            (f_coef * field%dB(1,2)) * mat6(3,:)
  endif
endif


! Electric kick.

if (ix_elec_max > -1) then
  orb0 = orbit
  rel_p0 = 1 + orb0%vec(6)
  ps2 = rel_p0**2 - orb0%vec(2)**2 - orb0%vec(4)**2
  ps = sqrt(ps2) / rel_p0
  f_coef = coef * step_len * (1 + ele%value(g$) * orb0%vec(1)) * charge / (ps * orb0%beta * orb0%p0c)
  Kx = f_coef * field%E(1)
  Ky = f_coef * field%E(2)
  alpha = (kx * (2*orb0%vec(2) + kx) + ky * (2*orb0%vec(4) + ky)) / rel_p0**2

  orbit%vec(2) = orb0%vec(2) + Kx
  orbit%vec(4) = orb0%vec(4) + Ky
  orbit%vec(6) = orb0%vec(6) + rel_p0 * sqrt_one(alpha)

  orbit%beta = (1 + orbit%vec(6)) / sqrt(ps2 + orbit%vec(2)**2 + orbit%vec(4)**2 + (mass_of(orbit%species)/orbit%p0c)**2)

  orbit%vec(5) = orb0%vec(5) * orbit%beta/ orb0%beta

  if (logic_option(.false., make_matrix)) then
    df_coef_dx = coef * step_len * ele%value(g$) * charge / (ps * orb0%beta * orb0%p0c)
    df_dps_coef = 1 / (ps**2 * rel_p0**2)
    mc2 = mass_of(orbit%species)
    pc0 = rel_p0 * orb0%p0c
    dk_dp = (mc2 * orb0%beta / (rel_p0 * orb0%p0c))**2 / rel_p0 + df_dps_coef * (orb0%vec(2)**2 + orb0%vec(4)**2) / rel_p0
    E0 = orb0%p0c * rel_p0 / orb0%beta
    E1 = orbit%p0c * (1 + orbit%vec(6)) / orbit%beta

    call mat_make_unit(kmat)
    kmat(2,1) =  f_coef * field%dE(1,1) + df_coef_dx * field%E(1)
    kmat(2,2) =  1 + f_coef * field%E(1) * orb0%vec(2) * df_dps_coef
    kmat(2,3) =  f_coef * field%dE(1,2)
    kmat(2,4) =  f_coef * field%E(1) * orb0%vec(4) * df_dps_coef
    kmat(2,6) = -f_coef * field%E(1) * (mc2**2 * orb0%p0c / (E0**2 * pc0) + df_dps_coef * (orb0%vec(2)**2 + orb0%vec(4)**2) / rel_p0)

    kmat(4,1) =  f_coef * field%dE(2,1) + df_coef_dx * field%E(2)
    kmat(4,2) =  f_coef * field%E(2) * orb0%vec(2) * df_dps_coef
    kmat(4,3) =  f_coef * field%dE(2,2)
    kmat(4,4) =  1 + f_coef * field%E(2) * orb0%vec(4) * df_dps_coef
    kmat(4,6) = -f_coef * field%E(2) * (mc2**2 * orb0%p0c / (E0**2 * pc0) + df_dps_coef * (orb0%vec(2)**2 + orb0%vec(4)**2) / rel_p0)

    f = 1 / (1 + orbit%vec(6))
    kmat(6,1) = f * (orbit%vec(2) * (f_coef * field%dE(1,1) + df_coef_dx * field%E(1)) + orbit%vec(4) * f_coef * field%dE(2,1))
    kmat(6,2) = f * Kx * (1.0_rp + orbit%vec(2) * orb0%vec(2) * df_dps_coef)
    kmat(6,3) = f * (orbit%vec(2) * f_coef * field%dE(1,2) + orbit%vec(4) * f_coef * field%dE(2,2))
    kmat(6,4) = f * Ky * (1.0_rp + orbit%vec(4) * orb0%vec(4) * df_dps_coef)
    kmat(6,6) = f * (rel_p0 - orbit%vec(2) * dk_dp * Kx - orbit%vec(4) * dk_dp * Ky)

    kmat(5,1:4) = (mc2**2 * orb0%p0c * orb0%vec(5) / (orb0%beta * E1**3)) * kmat(6,1:4) 
    kmat(5,5) = orbit%beta / orb0%beta
    kmat(5,6) = orb0%vec(5) * mc2**2 * orbit%p0c * (kmat(6,6) / (orb0%beta * E1**3) - orbit%beta / (orb0%beta**2 * E0**3))

    mat6 = matmul(kmat, mat6)
  endif
endif

end subroutine apply_multipole_kicks

end subroutine track_a_bend

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine sbend_body_with_k1_map (ele, param, n_step, orbit, mat6, make_matrix)
!
! Subroutine to calculate for a single step the transfer matrix and/or 
! ending coordinates for a sbend with a finite k1 but without a tilt.
!
! Input:
!   ele          -- Ele_struct: Sbend element.
!   param        -- Lat_param_struct: Branch parameters.
!   n_step       -- Integer: Number of steps to divide the bend into.
!                     Only one step is taken by this routine.
!   orbit        -- coord_struct: Orbit at beginning of the bend.
!   mat6(6,6)    -- Real(rp), optional: Transfer matrix before element.
!   make_matrix  -- logical, optional: Propagate the transfer matrix? Default is false.
!
! Output:
!   orbit      -- coord_struct: Ending coordinates.
!   mat6(6,6)  -- Real(rp), optional: Transfer matrix with body added in.
!-

subroutine sbend_body_with_k1_map (ele, param, n_step, orbit, mat6, make_matrix)

use bmad, except_dummy => sbend_body_with_k1_map

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orbit

real(rp), optional :: mat6(6,6)
real(rp) mat6_i(6,6)
real(rp) g, g_err, length
real(rp) k_1, k_x, x_c, om_x, om_y, tau_x, tau_y, arg, s_x, c_x, s_y, c_y, r(6)
real(rp) z0, z1, z2, z11, z12, z22, z33, z34, z44
real(rp) dom_x, dom_xx, dx_c, dc_x, ds_x, dom_y, dom_yy, dc_y, ds_y, dcs_x, dcs_y
real(rp) g_tot, rel_p, rel_p2, rel_charge_dir
real(rp) rel_pc, px, py, pxy2, pz

integer n_step
logical, optional :: make_matrix

! Degenerate case

rel_charge_dir = rel_tracking_charge_to_mass(orbit, param) * ele%orientation * orbit%direction

k_1 = ele%value(k1$) * rel_charge_dir
g = ele%value(g$)
g_tot = (g + ele%value(g_err$)) * rel_charge_dir
g_err = g_tot - g
length = ele%value(l$) / n_step

!

g_tot = g + g_err
rel_p = (1 + orbit%vec(6))
rel_p2 = rel_p**2


k_x = k_1 + g * g_tot
x_c = (g * rel_p - g_tot) / k_x

om_x = sqrt(abs(k_x) / rel_p)
om_y = sqrt(abs(k_1) / rel_p)

tau_x = -sign (1.0_rp, k_x)
tau_y =  sign (1.0_rp, k_1)

arg = om_x * length
if (arg < 1d-6) then
  s_x = (1 + tau_x * arg**2 / 6) * length
  c_x = 1 + tau_x * arg**2 / 2
  z2 = g * length**2 / (2 * rel_p)
elseif (k_x > 0) then
  s_x = sin(arg) / om_x
  c_x = cos(arg)
  z2 = tau_x * g * (1 - c_x) / (rel_p * om_x**2)
else
  s_x = sinh(arg) / om_x
  c_x = cosh(arg)
  z2 = tau_x * g * (1 - c_x) / (rel_p * om_x**2)
endif

arg = om_y * length
if (arg < 1d-6) then
  s_y = (1 + tau_y * arg**2 / 6) * length
  c_y = 1 + tau_y * arg**2 / 2
elseif (k_1 < 0) then
  s_y = sin(om_y * length) / om_y
  c_y = cos(om_y * length)
else
  s_y = sinh(om_y * length) / om_y
  c_y = cosh(om_y * length)
endif

r = orbit%vec
r(1) = r(1) - x_c

!

z0  = -g * x_c * Length
z1  = -g * s_x
z11 = tau_x * om_x**2 * (length - c_x * s_x) / 4
z12 = -tau_x * om_x**2 * s_x**2 / (2 * rel_p) 
z22 = -(length + c_x * s_x) / (4 * rel_p2) 
z33 = tau_y * om_y**2 * (length - c_y * s_y) / 4
z34 = -tau_y * om_y**2 * s_y**2 / (2 * rel_p) 
z44 = -(length + c_y * s_y) / (4 * rel_p2)

! Jacobian matrix

if (logic_option(.false., make_matrix)) then

  dom_x = -om_x / (2 * rel_p)
  dom_xx = -1 / (2 * rel_p)  ! [d(om_x) / d(p_z)] / om_x
  dx_c = g / k_x
  dc_x = tau_x * s_x * om_x * dom_x * length
  ds_x = (c_x * length - s_x) * dom_xx 

  dom_y = -om_y / (2 * rel_p)
  dom_yy = -1 / (2 * rel_p)  ! [d(om_y) / d(p_z)] / om_y
  dc_y = tau_y * s_y * om_y * dom_y * length
  ds_y = (c_y * length - s_y) * dom_yy

  dcs_x = c_x * ds_x + dc_x * s_x
  dcs_y = c_y * ds_y + dc_y * s_y

  mat6_i = 0

  mat6_i(1,1) = c_x
  mat6_i(1,2) = s_x / rel_p
  mat6_i(1,6) = dx_c * (1 - c_x) + dc_x * r(1) + &
              ds_x * r(2) / rel_p - s_x * r(2) / rel_p2
  mat6_i(2,1) = tau_x * om_x**2 * rel_p * s_x
  mat6_i(2,2) = c_x
  mat6_i(2,6) = tau_x * r(1) * 2 * om_x * dom_x * rel_p * s_x + &
                tau_x * r(1) * om_x**2 * s_x + &
                tau_x * r(1) * om_x**2 * rel_p * ds_x - &
                tau_x * dx_c * om_x**2 * rel_p * s_x + dc_x * r(2)

  mat6_i(3,3) = c_y
  mat6_i(3,4) = s_y / rel_p
  mat6_i(3,6) = dc_y * r(3) + ds_y * r(4) / rel_p - s_y * r(4) / rel_p2
  mat6_i(4,3) = tau_y * om_y**2 * rel_p * s_y
  mat6_i(4,4) = c_y
  mat6_i(4,6) = tau_y * r(3) * 2 * om_y * dom_y * rel_p * s_y + &
                tau_y * r(3) * om_y**2 * s_y + &
                tau_y * r(3) * om_y**2 * rel_p * ds_y + &
                dc_y * r(4)

  mat6_i(5,1) = z1 + 2 * z11 * r(1) +     z12 * r(2)  
  mat6_i(5,2) = z2 +     z12 * r(1) + 2 * z22 * r(2)
  mat6_i(5,3) =      2 * z33 * r(3) +     z34 * r(4)  
  mat6_i(5,4) =          z34 * r(3) + 2 * z44 * r(4)
  mat6_i(5,5) = 1
  mat6_i(5,6) = -dx_c * (z1 + 2 * z11 * r(1) + z12 * r(2)) - & 
                g * length * dx_c - g * ds_x * r(1) - &           ! dz0 & dz1
                tau_x * g * dc_x * r(2) / (om_x**2 * rel_p) - &   ! dz2
                (z11 / rel_p + tau_x * om_x**2 * dcs_x / 4) * r(1)**2 - &
                (2 * z12 / rel_p + tau_x * om_x**2 * s_x * ds_x / rel_p) * r(1) * r(2) - &
                (2 * z22 / rel_p + dcs_x / (4 * rel_p2)) * r(2)**2 - &
                (z33 / rel_p + tau_y * om_y**2 * dcs_y / 4) * r(3)**2 - &
                (2 * z34 / rel_p + tau_y * om_y**2 * s_y * ds_y / rel_p) * r(3) * r(4) - &
                (2 * z44 / rel_p + dcs_y / (4 * rel_p2)) * r(4)**2

  mat6_i(6,6) = 1

  mat6 = matmul(mat6_i, mat6)

endif

! Ending coords

orbit%vec(1) = c_x * r(1) + s_x * r(2) / rel_p + x_c
orbit%vec(2) = tau_x * om_x**2 * rel_p * s_x * r(1) + c_x * r(2)
orbit%vec(3) = c_y * r(3) + s_y * r(4) / rel_p
orbit%vec(4) = tau_y * om_y**2 * rel_p * s_y * r(3) + c_y * r(4)
orbit%vec(5) = r(5) + z0 + z1 * r(1) + z2 * r(2) + &
               z11 * r(1)**2 + z12 * r(1) * r(2) + z22 * r(2)**2 + &
               z33 * r(3)**2 + z34 * r(3) * r(4) + z44 * r(4)**2 

end subroutine sbend_body_with_k1_map
