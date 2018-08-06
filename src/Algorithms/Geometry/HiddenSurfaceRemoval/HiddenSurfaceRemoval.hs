module Algorithms.Geometry.HiddenSurfaceRemoval.HiddenSurfaceRemoval where

import           Control.Applicative
import           Control.Lens
import           Data.Ext
import qualified Data.Foldable as F
import           Data.Functor.Classes
import           Data.Geometry.Arrangement
import           Data.Geometry.HyperPlane
import           Data.Geometry.Line
import           Data.Geometry.LineSegment
import           Data.Geometry.PlanarSubdivision
import           Data.Geometry.Point
import           Data.Geometry.Polygon (centroid)
import           Data.Geometry.Properties
import           Data.Geometry.Triangle
import qualified Data.List as List
import           Data.Maybe
import           Data.Proxy
import           Data.Semigroup
import           Data.UnBounded
import           Data.Util
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
--------------------------------------------------------------------------------

type PriQ a = [a]

render         :: (Ord r, Fractional r)
               => proxy s
               -> Point 3 r -- ^ the viewpoint
               -> [Triangle 2 v r :+ (Triangle 3 q r :+ f)]
               -> Arrangement s () () (Maybe f) r
render px vp ts = undefined
  where
    arr = constructArrangement px $ concatMap f ts
    f t = map (\s -> supportingLine s :+ SP s t) . sideSegments $ t^.core


type Tri v q f r = Triangle 2 v r :+ (Triangle 3 q r :+ f)
type T v q f r = SP (LineSegment 2 v r) (Tri v q f r)


-- -- | Given a point on the boundary of a projected triangle T, get the point in
-- -- R^3 on the boundary of the triangle (in R^3)
-- liftToR3              :: (Ord r, Fractional r) => Point 2 r -> T v q f r -> Point 3 r
-- liftToR3 q (SP seg t) = Point $ lambda *^ (h s) ^+^ (1-lambda) *^ (h e)
--   where
--     LineSegment' (s :+ _) (e :+ _) = seg
--     lambda = scalarMultiple (q .-. s) (e .-. s)

--     h p = fromMaybe (error "liftToR3: fromJust.") $ lookup q vs'
--     vs' = zip (vs $ t^.core) (vs $ t^.extra.core)

--     vs                  :: Triangle d q r -> [Point d r]
--     vs (Triangle a b c) = map (^.core) [a,b,c]

-- -- | Given a point on the projected triangle tw, get the point in
-- -- R^3 on the corresponding triangle in R^3
liftToR3              :: (Ord r, Fractional r) => Point 2 r -> Tri v q f r -> Point 3 r
liftToR3 q (t2 :+ t3) = fromBarricentric (toBarricentric q t2) t^3.core

data EdgeSide = L | R | None deriving (Show,Eq)



-- | Given a view point vp and a point q, order the two triangles based on their
-- first intersection with the line through vp and q.
compareDepthOrder          :: (Ord r, Fractional r)
                           => Point 3 r -> Point 3 r
                           -> Tri v q f r -> Tri v q f r -> Ordering
compareDepthOrder vp q a b = distOf a `compare` distOf b
  where
    l        = lineThrough vp q
    distOf t = maybe err (squaredEuclideanDist vp) $ intersectionPoint l (t^.extra.core)
    err      = error "HiddenSurfaceremoval. depthOrdert: no intersection"


-- | Given a view point vp and a projected point q, order the two triangles
-- based on their first intersection with the line through vp and q.
--
-- pre: the projected point occurs in the projection of the first triangle
compareDepthOrder'         :: (Ord r, Fractional r)
                           => Point 3 r -> Point 2 r
                           -> Tri v q f r -> Tri v q f r -> Ordering
compareDepthOrder' vp q a = compareDepthOrder vp (liftToR3 q a) a



-- | computes the intersection point between l and the supporting plane of t
intersectionPoint     :: (Ord r, Fractional r)
                      => Line 3 r -> Triangle 3 p r -> Maybe (Point 3 r)
intersectionPoint l t = asA (Proxy :: Proxy (Point 3 r)) $ l `intersect` supportingPlane t

--
-- >>> fromAssignments id 5 [0 :+ 0, 1 :+ 1, 3 :+ 3, 4 :+ 4]
-- [Just 0,Just 1,Nothing,Just 3,Just 4]
fromAssignments            :: (k -> Int) -> Int -> [k :+ v] -> V.Vector (Maybe v)
fromAssignments idxOf n as = V.create $ do
                               vec <- MV.replicate n Nothing
                               mapM_ (\(k :+ v) -> MV.modify vec (<|> Just v) (idxOf k)) as
                               pure vec


dartAssignments :: Arrangement s () (T v q f r) (T v q f r) r -> [Dart s :+ EdgeSide]
dartAssignments = undefined



-- | Computes a face assignment for all faces by just naively computing the first
-- visible triangle for every face. We do so by just sampling a point in the face
--
-- running time: \(O(n^3)\), where \(n\) is the number of input triangles.
naiveAssignment           :: (Ord r, Fractional r)
                          => Point 3 r
                          -> Arrangement s () (T v q f r) () r
                          -> [Tri v q f r]
                          -> [FaceId' s :+ Maybe (Tri v q f r)]
naiveAssignment vp arr ts = mapMaybe f . V.toList $ faces' ps
  where
    f i = let (pg :+ _) = rawFaceBoundary i ps
              c         = centroid pg
              mt        = minimumBy' (compareDepthOrder' vp c) $ filter (c `inTriangle`) ts
          in (\t -> i :+ Just t) <$> mt
    ps = arr^.subdivision
  -- observe that all faces in the arrangement are convex, so the centroid
  -- lies inside the face
  --
  -- observe that since we explicitly filter the triangles to contain c, we can indeed
  -- safely use compareDepthOrder'

minimumBy'     :: Foldable f => (a -> a -> Ordering) -> f a -> Maybe a
minimumBy' cmp = topToMaybe  . List.minimumBy (liftCompare cmp)
               . (Top :) . fmap ValT . F.toList


--------------------------------------------------------------------------------

-- scanAll     :: (Ord r, Fractional r)
--             => Arrangement s () (T v q f r) () r
--             -> [FaceId' s :+ Maybe (T v q f r)]
-- scanAll arr = concatMap (scanLine arr) . V.toList $ arr^.inputLines


-- -- | Sweeps along line l in the arrangement, maintaining the first/topmost
-- -- visible triangle during the sweep. While doing this we thus figure out
-- -- 1) which triangle is the top-triangle just left of the line
-- -- 2) which triangle is the top-triangle just right of the line.
-- --
-- -- We collect this information in the form of assignments: i.e. for a
-- -- faceId we simply remember what data to assign it to.
-- -- (we do this so that we can process all these assignments in a batch.)
-- scanLine              :: (Ord r, Fractional r)
--                       => Arrangement s () (T v q f r) () r
--                       -> Line 2 r :+ T v q f r
--                       -> [FaceId' s :+ Maybe (T v q f r)]
-- scanLine arr (l :+ t) = view _1
--                       . List.foldl' f (STR [] mempty mempty) $ traverseLine l arr
--   where
--     f (STR fs lst rst) d = STR fs lst rst
--       -- | isActive d = STR (fa <> fs) st
--       --                  | otherwise  = STR ds fs st





-- data Changes a = Changes { _enterLeft  :: !a
--                          , _enterRight :: !a
--                          , _exitLeft   :: !a
--                          , _exitRight  :: !a
--                          } deriving (Show,Eq, Functor, Foldable, Traversable)

-- stateChanges          :: Arrangement s () (T v q f r) () r -> Dart s -> Dart s
--                       -> Changes [T v q f r]
-- stateChanges arr pd d = Changes lEnters rEnters lLeaves rLeaves
--   where
--     lEnters = []
--     rEnters = []
--     lLeaves = []
--     rLeaves = []
