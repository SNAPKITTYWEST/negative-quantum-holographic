-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:4eb517a7e70e3ffd3b3a79fde4d00a7dc581c4c56a4c9d232c5763641dc017d8
--
\begin{code}
module ResonanceMasonry where

import qualified Data.Set as S
import Data.Set (Set)

data GeoRel = Orthogonal | Horizontal | Vertical | Symmetric | Congruent
  deriving (Eq, Ord, Show)
data EthRel = RectitudeRel | EquityRel | IntegrityRel | SelfConsistent | Coherent
  deriving (Eq, Ord, Show)
data Geometry = Geometry { geoRels :: Set GeoRel, loadBearing :: Bool }
data Ethic = Ethic { ethRels :: Set EthRel, trustBearing :: Bool }
data OpState = OpState { stone :: Int, geometry :: Geometry }
data SpState = SpState { agent :: Int, ethic :: Ethic }

allowedGeo :: Set GeoRel
allowedGeo = S.fromList [Orthogonal, Horizontal, Vertical, Symmetric]

{-@ reflect psiRel @-}
psiRel :: GeoRel -> EthRel
psiRel Orthogonal = RectitudeRel
psiRel Horizontal = EquityRel
psiRel Vertical = IntegrityRel
psiRel Symmetric = SelfConsistent
psiRel Congruent = Coherent

{-@ reflect psiGeometry @-}
psiGeometry :: Geometry -> Ethic
psiGeometry g = Ethic (S.map psiRel (geoRels g)) (loadBearing g)

psiAgent :: Int -> Int
psiAgent = id

{-@ reflect psi @-}
psi :: OpState -> SpState
psi s = SpState (psiAgent (stone s)) (psiGeometry (geometry s))

{-@ reflect opInvariant @-}
opInvariant :: Bool -> OpState -> Bool
opInvariant nonEmpty s =
  geoRels (geometry s) `S.isSubsetOf` allowedGeo &&
  (not nonEmpty || not (S.null (geoRels (geometry s)))) &&
  loadBearing (geometry s)

{-@ reflect spInvariant @-}
spInvariant :: SpState -> Bool
spInvariant s =
  ethRels (ethic s) `S.isSubsetOf` S.fromList [RectitudeRel,EquityRel,IntegrityRel,SelfConsistent]
  && trustBearing (ethic s)

{-@ reflect lightMasonry @-}
lightMasonry :: SpState -> Bool
lightMasonry s = spInvariant s && not (S.null (ethRels (ethic s)))

-- L1 is represented as a refinement obligation for callers:
-- opInvariant True s implies lightMasonry (psi s).
\end{code}
