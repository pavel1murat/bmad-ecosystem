!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function pointer_to_multipass_lord (ele, ix_pass, super_lord) result (multi_lord)
!
! Routine to find the multipass lord of a lattice element.
! A multi_lord will be found for:
!   multipass_slaves
!   super_lords that are slaves of a multipass_lord
!   super_slaves whose super_lord is a slave of a multipass_lord
!
! Input:
!   ele   -- Ele_struct: Lattice element.
!
! Output:
!   ix_pass    -- Integer, optional: Multipass turn number.
!                      Set to -1 if element is not a multipass slave
!   super_lord -- Ele_struct, pointer, optional: super_lord of the element.
!                      Set to NULL if ele is not a super_slave.
!   multi_lord -- Ele_struct, pointer: multipass_lord if there is one.
!                      Set to NULL if there is no multipass_lord.
!-

function pointer_to_multipass_lord (ele, ix_pass, super_lord) result (multi_lord)

use equal_mod, except_dummy => pointer_to_multipass_lord

implicit none

type (ele_struct) ele
type (ele_struct), pointer :: multi_lord, sup_lord
type (ele_struct), pointer, optional :: super_lord

integer, optional :: ix_pass

!

nullify (multi_lord)
if (present(super_lord)) nullify (super_lord)
if (present(ix_pass)) ix_pass = -1

if (ele%slave_status == multipass_slave$) then
  multi_lord => pointer_to_lord(ele, 1, ix_slave = ix_pass)
  return
endif

if (ele%slave_status == super_slave$) then
  sup_lord => pointer_to_lord(ele, 1)
  if (present(super_lord)) super_lord => sup_lord

  if (sup_lord%slave_status /= multipass_slave$) return
  multi_lord => pointer_to_lord(sup_lord, 1, ix_slave = ix_pass)
endif

end function pointer_to_multipass_lord

