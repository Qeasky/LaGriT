 
 
 
C******************************************************************************
C*
C*  EXTRACT_SURFMESH -- Extract the boundary of a mesh (surface mesh from a
c*  solid meshmesh
C*                      and edge mesh from a surface mesh)
C*
C*      CALL EXTRACT_SURFMESH (CMOOUT, CMOIN, IERROR)
C*
C*    This routine extracts the boundary of a mesh. If the original mesh is a solid
C*    mesh, it extracts the surface mesh. If it is a surface mesh, it extracts the
C*    edge mesh. If the interface elements have "uses" i.e. "parent-child" nodes,
C* then
C*    only the parent nodes and elements are extracted.
C*
C*
C*    Because of the nature of this extraction, not all attributes in the output
C*    mesh object are given values.  Among the array-valued attributes, only
C*    XIC, YIC, ZIC, ITET, ITETOFF, ITETTYP, and ICR1 are set.  In particular
C*    JTET is not set, because it is possible, in general, for more than two
C*    cells to share a face in a network.  The ICONTAB array is copied from the
C*    input mesh object to the output mesh object.
C*
C*    Two element based attributes, "itetclr0" and "itetclr1" are added to the output
C*    mesh indicating the material regions on each side of the mesh faces, i.e., the
C*    color of elements that existed on each side of a face in the original mesh.
C*    The convention is that the "itetclr0" indicates the color of the
C*     elements on the
C*    side of the face normal (0 if the face is on an external boundary) and
C*    "itetclr1"
C*    indicates the color of the elements on the opposite side of the normal.
C*                |
C*                |------> normal
C*                |
C*      mregion5  |  mregion1               For this face itetclr0 = 1
C*                |                                       itetclr1 = 5
C*               Face
C*
C*    The output mesh object is given an additional node-based attribute named
C*    "map" which provides the mapping from nodes in the extracted interface
C*    network to (parent) nodes in the input mesh object; that is, MAP(J) is
C*    the parent node in the input mesh object that corresponds to node J in
C*    the output mesh object.
C*
C*  INPUT ARGUMENTS
C*
C*    CMOOUT -- Output mesh object name.
C*    CMOIN  -- Input mesh object name.
C*
C*  OUTPUT ARGUMENTS
C*
C*    IERROR -- Error flag
C*
C*  CHANGE HISTORY --
C*
C*
C*   $Log: extract_surfmesh.f,v $
C*   Revision 2.00  2007/11/05 19:45:54  spchu
C*   Import to CVS
C*
CPVCS    
CPVCS       Rev 1.5   01 Oct 2007 08:16:16   gable
CPVCS    Modified to give warning and continue instead of crash when the MO
CPVCS    does not exist or is empty.
CPVCS    
CPVCS       Rev 1.4   07 Mar 2002 09:56:06   gable
CPVCS    Added error check so code will return rather than
CPVCS    crash if number of elements is zero.
CPVCS    
CPVCS       Rev 1.3   14 May 2001 10:56:58   kuprat
CPVCS    New 'external' option for only extracting exterior surface mesh.
CPVCS    
CPVCS       Rev 1.2   22 Mar 2000 08:28:44   dcg
CPVCS    changes for HP compatibility
CPVCS
 
CPVCS       Rev 1.1   08 Feb 2000 15:56:52   gable
 
CPVCS    RVG Added 3rd attribute, facecol.
 
CPVCS
 
CPVCS       Rev 1.0   07 Feb 2000 18:35:24   gable
 
CPVCS    Initial revision.
 
C*  Adapted from extract_network
C*
C****************************************************************************
 
      subroutine extract_surfmesh (cmoout, cmoin, cmode, ierror)
      implicit none
 
      character*(*) cmoout, cmoin, cmode
      integer ierror
 
      include "local_element.h"
 
C      ** Define the element type associated with each element face.  It is
C      ** purely coincidental that the number of points on a face is the same
C      ** as the face element type.  (Move into local_element.h/blockcom.f?)
 
      integer ifacetype(maxnef,nelmtypes)
      data ifacetype / 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     *                 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
     *                 2, 2, 2, 0, 0, 0, 0, 0, 0, 0,
     *                 2, 2, 2, 2, 0, 0, 0, 0, 0, 0,
     *                 3, 3, 3, 3, 0, 0, 0, 0, 0, 0,
     *                 4, 3, 3, 3, 3, 0, 0, 0, 0, 0,
     *                 3, 3, 4, 4, 4, 0, 0, 0, 0, 0,
     *                 4, 4, 4, 4, 4, 4, 0, 0, 0, 0,
     *                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     *                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
     *               /
 
      pointer (ipxic,xic), (ipyic,yic), (ipzic,zic)
      real*8 xic(*), yic(*), zic(*)
 
      pointer (ipitet,itet), (ipitetoff,itetoff), (ipitettyp,itettyp),
     &        (ipjtet,jtet), (ipjtetoff,jtetoff), (ipitetclr,itetclr),
     &        (ipitp1,itp1), (ipisn1,isn1), (ipicr1,icr1),
     &        (ipicontab,icontab)
      integer itet(*), jtet(*), itetoff(*), jtetoff(*), itettyp(*),
     &        itetclr(*), itp1(*), isn1(*), icr1(*), icontab(*)
 
      pointer (ipxicn,xicn), (ipyicn,yicn), (ipzicn,zicn)
      real*8 xicn(*), yicn(*), zicn(*)
 
      pointer (ipitetn,itetn), (ipitetoffn,itetoffn), (ipcpmap,cpmap),
     &        (ipitettypn,itettypn), (ipicr1n,icr1n), (ipfmap,fmap),
     &        (ipicontabn,icontabn), (ipmap,bmap), (ipclr0,clr0),
     &        (ipclr1,clr1), (ipfacecol,facecol)
      integer itetn(*), itetoffn(*), itettypn(*), icr1n(*),
     &        icontabn(*), bmap(*), cpmap(*), fmap(*),
     &        clr0(*), clr1(*), facecol(*), uniqcols(10000)
 
      integer i, j, k, kk, m, n, ilen, ityp, nnnpe, nnfpe, nnepe, jnbr
      integer nncells, nnnodes, minft, maxft, nfpe, nconbnd, node
      integer nnodes, ncells, topo_dim, geom_dim, mbndry, ncon50
      integer tmpcol, ncols, found, imode
 
      character*132 cbuf, logmess
      character*32 isubname
 
      isubname = 'extract_surfmesh'
      ierror = 0

c.... If cmode='external', we only generate exterior surface mesh.
c.... Otherwise, we generate surface mesh for all (interior and
c.... exterior) surfaces.
      if (cmode(1:8).eq.'external') then
         imode=1
      else
         imode=0
      endif

      ncols = 0
C 
C     Check that input mesh object exists.
C
      call cmo_exist(cmoin,ierror)
      if(ierror .ne. 0)then
          write(logmess,'(a)')'WARNING: EXTRACT_SURFMESH'
          call writloga('default',0,logmess,0,ierror)
          write(logmess,'(a)')'WARNING: INPUT MO DOES NOT EXIST'
          call writloga('default',0,logmess,0,ierror)
          write(logmess,'(a)')'WARNING: No action'
          call writloga('default',0,logmess,0,ierror)
          return
      endif
C     ***
C     *** Get the attributes from the input mesh object.
 
      call cmo_get_info('ndimensions_topo',cmoin,topo_dim,ilen,ityp,
     &                                                           ierror)
      call cmo_get_info('ndimensions_geom',cmoin,geom_dim,ilen,ityp,
     &                                                           ierror)
      call cmo_get_info('nelements',cmoin,ncells,ilen,ityp,ierror)
      call cmo_get_info('nnodes',cmoin,nnodes,ilen,ityp,ierror)
      call cmo_get_info('faces_per_element',cmoin,nfpe,ilen,ityp,ierror)
      call cmo_get_info('mbndry',cmoin,mbndry,ilen,ityp,ierror)
      call cmo_get_info('itet',cmoin,ipitet,ilen,ityp,ierror)
      call cmo_get_info('jtet',cmoin,ipjtet,ilen,ityp,ierror)
      call cmo_get_info('itetoff',cmoin,ipitetoff,ilen,ityp,ierror)
      call cmo_get_info('jtetoff',cmoin,ipjtetoff,ilen,ityp,ierror)
      call cmo_get_info('itetclr',cmoin,ipitetclr,ilen,ityp,ierror)
      call cmo_get_info('itettyp',cmoin,ipitettyp,ilen,ityp,ierror)
      call cmo_get_info('itp1',cmoin,ipitp1,ilen,ityp,ierror)
      call cmo_get_info('isn1',cmoin,ipisn1,ilen,ityp,ierror)
      call cmo_get_info('icr1',cmoin,ipicr1,ilen,ityp,ierror)
      call cmo_get_info('xic',cmoin,ipxic,ilen,ityp,ierror)
      call cmo_get_info('yic',cmoin,ipyic,ilen,ityp,ierror)
      call cmo_get_info('zic',cmoin,ipzic,ilen,ityp,ierror)
C
C     Quick Error check to avoid attempt to allocate zero length arrays.
C
      if(ncells .eq. 0)then
          write(logmess,'(a)')'WARNING: EXTRACT_SURFMESH'
          call writloga('default',0,logmess,0,ierror)
          write(logmess,'(a)')'WARNING: nelements = 0'
          call writloga('default',0,logmess,0,ierror)
          write(logmess,'(a)')'WARNING: No action'
          call writloga('default',0,logmess,0,ierror)
          return
      endif
C 
C     ***
C     *** Preliminary pass through the cells, counting faces and nodes.
 
      call mmgetblk ('cpmap', isubname, ipcpmap, nnodes, 1, ierror)
      call mmgetblk ( 'fmap', isubname,  ipfmap, nnodes, 1, ierror)
      call unpackpc (nnodes, itp1, isn1, cpmap)
      do j = 1, nnodes
        fmap(j) = 0
      end do
 
      nncells = 0
      nnnodes = 0
      minft = nelmtypes
      maxft = 0
 
      do j = 1, ncells
        do k = 1, nelmnef(itettyp(j))
          if (jtet(k+jtetoff(j)) .gt. mbndry) then
            jnbr = 1 + (jtet(k+jtetoff(j)) - mbndry - 1) / nfpe
          else if (jtet(k+jtetoff(j)) .eq. mbndry) then
            jnbr = 0
          else
            jnbr = -1
          endif
 
c...This long 'if' test checks if the current face is at an internal or external
c...boundary (non-EXTERNAL mode <==> imode=0) or if the current face is at
c...an external boundary (EXTERNAL mode <==> imode=1).
          if (((imode.eq.0).and.(jnbr.ne.-1)).or.((imode.eq.1).and.(jnbr
     &       .eq.0))) then

            if ((jnbr .eq. 0) .or. (itetclr(jnbr) .gt. itetclr(j))) then
              nncells = nncells + 1
              minft = min( ifacetype(k,itettyp(j)), minft )
              maxft = max( ifacetype(k,itettyp(j)), maxft )
              do i = 1, ielmface0(k,itettyp(j))
                node = cpmap(itet(itetoff(j)+ielmface1(i,k,itettyp(j))))
                if (fmap(node) .eq. 0) then
                  nnnodes = nnnodes + 1
                  fmap(node) = nnnodes
                end if
              end do
            end if
          end if
        end do
      end do
 
      if (nncells .eq. 0) then
        logmess = 'Input mesh object has no material interfaces.'
        call writloga ('default', 0, logmess, 0, ierror)
        return
      end if
 
C      ** Determine the type of the extracted mesh.
      if (minft.eq.ifelmlin .and. maxft.eq.ifelmlin) then
        nnnpe = nelmnen(ifelmlin)
        nnfpe = nelmnef(ifelmlin)
        nnepe = nelmnee(ifelmlin)
      else if (minft.eq.ifelmtri .and. maxft.eq.ifelmtri) then
        nnnpe = nelmnen(ifelmtri)
        nnfpe = nelmnef(ifelmtri)
        nnepe = nelmnee(ifelmtri)
      else if (minft.eq.ifelmqud .and. maxft.eq.ifelmqud) then
        nnnpe = nelmnen(ifelmqud)
        nnfpe = nelmnef(ifelmqud)
        nnepe = nelmnee(ifelmqud)
      else if (minft.eq.ifelmtri .and. maxft.eq.ifelmqud) then
        nnnpe = nelmnen(ifelmhyb)
        nnfpe = nelmnef(ifelmhyb)
        nnepe = nelmnee(ifelmhyb)
      else
        logmess = 'EXTRACT_NETWORK: PANIC!  bad minft/maxft values.'
        call writloga ('default', 0, logmess, 0, ierror)
        stop
      end if
 
C     ***
C     *** Create the output mesh object
 
      call cmo_exist (cmoout, ierror)
      if (ierror .eq. 0) call cmo_release (cmoout, ierror)
      call cmo_create (cmoout, ierror)
 
      call cmo_set_info('nnodes',cmoout,nnnodes,1,1,ierror)
      call cmo_set_info('nelements',cmoout,nncells,1,1,ierror)
      call cmo_set_info('ndimensions_topo',cmoout,topo_dim-1,1,1,ierror)
      call cmo_set_info('ndimensions_geom',cmoout,geom_dim,1,1,ierror)
      call cmo_set_info('nodes_per_element',cmoout,nnnpe,1,1,ierror)
      call cmo_set_info('faces_per_element',cmoout,nnfpe,1,1,ierror)
      call cmo_set_info('edges_per_element',cmoout,nnepe,1,1,ierror)
 
      call cmo_newlen (cmoout, ierror)
 
      call cmo_get_info('itet',cmoout,ipitetn,ilen,ityp,ierror)
      call cmo_get_info('itetoff',cmoout,ipitetoffn,ilen,ityp,ierror)
      call cmo_get_info('itettyp',cmoout,ipitettypn,ilen,ityp,ierror)
      call cmo_get_info('icr1',cmoout,ipicr1n,ilen,ityp,ierror)
      call cmo_get_info('xic',cmoout,ipxicn,ilen,ityp,ierror)
      call cmo_get_info('yic',cmoout,ipyicn,ilen,ityp,ierror)
      call cmo_get_info('zic',cmoout,ipzicn,ilen,ityp,ierror)
 
C      ** Add the output->input node mapping as an attribute of the
C      ** output mesh object.
      cbuf = "cmo/addatt/" // cmoout //
     &       "/map/vint/scalar/nnodes////0; finish"
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info ("map", cmoout, ipmap, ilen, ityp, ierror)
      do j = 1, nnodes
        if (fmap(j) .gt. 0) then
          bmap(fmap(j)) = j
        end if
      end do
 
C     itetclr0 is the color of the tet on the +ve side of the mesh face
C     (i.e. on the side of the normal) and itetclr1 is the color of the
C     tet on the -ve side of the mesh face (i.e. on the opposite side
C     of the mesh face normal)
 
      cbuf = "cmo/addatt/" // cmoout //
     &       "/itetclr0/vint/scalar/nelements////0; finish"
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info("itetclr0", cmoout, ipclr0, ilen, ityp, ierror)
      cbuf = "cmo/addatt/" // cmoout //
     &       "/itetclr1/vint/scalar/nelements////0; finish"
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info("itetclr1", cmoout, ipclr1, ilen, ityp, ierror)
      cbuf = "cmo/addatt/" // cmoout //
     &       "/facecol/vint/scalar/nelements////0; finish"
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info("facecol", cmoout,ipfacecol, ilen, ityp, ierror)
 
 
C     ***
C     *** Second pass through the cells.
 
      n = 0
      m = 0
 
      do j = 1, ncells
        do k = 1, nelmnef(itettyp(j))
          if (jtet(k+jtetoff(j)) .gt. mbndry) then
            jnbr = 1 + (jtet(k+jtetoff(j)) - mbndry - 1) / nfpe
          else if (jtet(k+jtetoff(j)) .eq. mbndry) then
            jnbr = 0
          else
            jnbr = -1
          endif
 
c...This long 'if' test checks if the current face is at an internal or external
c...boundary (non-EXTERNAL mode <==> imode=0) or if the current face is at
c...an external boundary (EXTERNAL mode <==> imode=1).
          if (((imode.eq.0).and.(jnbr.ne.-1)).or.((imode.eq.1).and.(jnbr
     &       .eq.0))) then

            if ((jnbr .eq. 0) .or. (itetclr(jnbr) .gt. itetclr(j))) then
              n = n + 1
              itettypn(n) = ifacetype(k,itettyp(j))
              itetoffn(n) = m
              m = m + nelmnen(itettypn(n))
              do i = 1, ielmface0(k,itettyp(j))
                node = cpmap(itet(itetoff(j)+ielmface1(i,k,itettyp(j))))
                itetn(itetoffn(n)+i) = fmap(node)
              enddo
 
C
C     We also have to assign the itetclr0 and itetclr1 appropriately
C     to indicate which model region was on which side of each face
C     Since the face is being constructed from element j, it will always
C     point out of the element and into the neighboring element. Also
C     since the lower color elements are processed first (see 'if' condition
C     above, we will get a consistent direction of faces for each boundary
C
 
              clr1(n) = itetclr(j)
              if (jnbr .eq. 0) then
                 clr0(n) = 0
              else
                 clr0(n) = itetclr(jnbr)
              endif
 
C
C     Derive a face color based on clr0 and clr1. Assumes that clr0 & clr1 are
C     at the most 15 bit integers (then if we LEFT SHIFT clr1 by 15 bits and
C     OR it with clr0 we will get a 30 bit integer). This will still not ensure
C     uniqueness of all model face numbers - one can have 2 disconnected patches
C     of faces pointing to the same two regions in the same order.
C
 
              tmpcol = clr1(n)
              tmpcol = tmpcol*(2**15)
              tmpcol = tmpcol+clr0(n)
 
              found = 0
              do kk = 1, ncols
                 if (uniqcols(kk) .eq. tmpcol) then
                    found = 1
                    goto 99
                 endif
              enddo
 
 99           if (found .eq. 1) then
                 facecol(n) = kk
              else
                 ncols = ncols + 1
                 uniqcols(ncols) = tmpcol
                 facecol(n) = ncols
              endif
            endif
          endif
        enddo
      enddo
 
C     ***
C     *** Copy node-based data into new mesh object.
 
      if (geom_dim .eq. 2) then
 
        do j = 1, nnnodes
          xicn(j) = xic(bmap(j))
          yicn(j) = yic(bmap(j))
          icr1n(j) = icr1(bmap(j))
        end do
 
      else if (geom_dim .eq. 3) then
 
        do j = 1, nnnodes
          xicn(j) = xic(bmap(j))
          yicn(j) = yic(bmap(j))
          zicn(j) = zic(bmap(j))
          icr1n(j) = icr1(bmap(j))
        end do
 
      end if
 
C      ** NOTE.  The following node-based attributes are left uninitialized:
C      ** ialias, imt1, itp1, isn1, ign1.  The following cell-based attributes
C      ** are left uninitialized: itetclr, jtet, jtetoff.
 
C     ***
C     *** Copy the constraint table into the new mesh object.
 
      cbuf = 'cmo/addatt/' // cmoout //
     &       '/ncon50/int/scalar/scalar/constant/permanent/x/0; finish'
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info ('ncon50',cmoin,  ncon50, ilen,ityp,ierror)
      call cmo_set_info ('ncon50',cmoout, ncon50, i,1,ierror)
 
      cbuf = 'cmo/addatt/' // cmoout //
     &       '/nconbnd/int/scalar/scalar/constant/permanent/x/0; finish'
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info ('nconbnd',cmoin,  nconbnd, ilen,ityp,ierror)
      call cmo_set_info ('nconbnd',cmoout, nconbnd, 1,1,ierror)
 
      cbuf = 'cmo/addatt/' // cmoout //
     &     '/icontab/vint/scalar/ncon50/constant/permanent/x/0; finish'
      call dotaskx3d (cbuf, ierror)
      call cmo_get_info ('icontab',cmoin,  ipicontab,  ilen,ityp,ierror)
      call cmo_get_info ('icontab',cmoout, ipicontabn, ilen,ityp,ierror)
      do j = 1, ncon50
       icontabn(j) = icontab(j)
      end do
 
      call set_jtetoff()
      cbuf = 'geniee; finish'
      call dotaskx3d(cbuf, ierror)
 
      call mmrelprt(isubname,ierror)
 
      return
      end