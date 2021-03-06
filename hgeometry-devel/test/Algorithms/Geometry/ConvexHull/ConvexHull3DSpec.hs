module Algorithms.Geometry.ConvexHull.ConvexHull3DSpec where

import qualified Algorithms.Geometry.ConvexHull.KineticDivideAndConquer as DivAndConc
import           Algorithms.Geometry.ConvexHull.Naive (ConvexHull)
import qualified Algorithms.Geometry.ConvexHull.Naive as Naive
import           Control.Lens
import           Control.Monad (forM, forM_)
import           Data.Ext
import           Data.Geometry.Point
import           Data.Geometry.Triangle
import           Data.Geometry.Vector
import qualified Data.List as List
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.List.Util(leaveOutOne)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.List.Set as ListSet
import           Data.Maybe
import           Data.RealNumber.Rational
import qualified Data.Set as Set
import           Data.Util
-- import           Algorithms.Util
import           Test.Hspec
import           Test.QuickCheck

--------------------------------------------------------------------------------

type R = RealNumber 10

spec :: Spec
spec = describe "3D ConvexHull tests" $ do
         it "manual on myPts"  $ (H $ Naive.lowerHull' myPts)  `shouldBe` myHull
         it "manual on myPts'" $ (H $ Naive.lowerHull' myPts') `shouldBe` myHull'

         it "same as naive on manual samples" $ do
           forM_ [myPts,myPts', buggyPoints, buggyPoints2, buggyPoints3]
             sameAsNaive

         it "same as naive on buggyPoints " $ sameAsNaive myPts


         it "same as naive quickcheck" $ property $ \(HI pts) -> sameAsNaive pts


spec' = describe "test" $ do
  it "same as naive on buggyPoints " $ sameAsNaive buggyPoints5

specShrink = describe "shrink" $ forM_ (zip [0..] $ leaveOutOne buggyPoints5') $ \(i,pts) ->
               it ("same as Naive " <> show i) $ sameAsNaive (mkBuggy pts)



newtype HullInput = HI (NonEmpty (Point 3 (RealNumber 10) :+ Int)) deriving (Eq,Show)

instance Arbitrary HullInput where
  arbitrary = (\as bs -> fromPts $ as <> bs) <$> setOf 3 arbitrary <*> arbitrary
    where
      fromPts pts = HI . NonEmpty.fromList
                 $ zipWith (:+) (fmap (realToFrac @Int @(RealNumber 10)) <$> Set.toList pts) ([0..])

-- FIXME: This actually works only for non-degenerate outputs. I.e. if
-- the output contains a face with more than three sides (i.e. not a
-- triangle) there are multiple, valid, ways of triangulating it.

-- sameAsNaive pts = (H $ DivAndConc.lowerHull' pts) `shouldBe` (H $ Naive.lowerHull' pts)

sameAsNaive pts = (HalfSpacesOf $ DivAndConc.lowerHull' pts)
                  `shouldBe`
                  (HalfSpacesOf $ Naive.lowerHull' pts)

newtype HalfSpaces p r = HalfSpacesOf (ConvexHull 3 p r) deriving Show

instance (Ord r, Fractional r) => Eq (HalfSpaces p r) where
  (HalfSpacesOf cha) == (HalfSpacesOf chb) = hsOf cha == hsOf chb
    where
      hsOf = flip ListSet.insertAll mempty . map Naive.upperHalfSpaceOf


newtype Hull p r = H (ConvexHull 3 p r) deriving (Show)

instance (Eq r, Ord p) => Eq (Hull p r) where
  (H ha) == (H hb) = f ha == f hb
    where
      f = List.sortOn g . map reorder
      g = fmap (^.extra) . (^._TriangleThreePoints)

reorder                  :: Ord p => Triangle 3 p r -> Triangle 3 p r
reorder (Triangle p q r) = let [p',q',r'] = List.sortOn (^.extra) [p,q,r] in Triangle p' q' r'


myPts :: NonEmpty (Point 3 R :+ Int)
myPts = NonEmpty.fromList $ [ Point3 5  5  0  :+ 2
                            , Point3 1  1  10 :+ 1
                            , Point3 0  10 20 :+ 0
                            , Point3 12 1  1  :+ 3
                            , Point3 22 20  1  :+ 4
                            ]

toTri       :: Eq a =>  NonEmpty (Point d r :+ a) -> Three a -> Triangle d a r
toTri pts t = let pt i = List.head $ NonEmpty.filter (\t -> t^.extra == i) pts
              in (t&traverse %~ pt)^.from _TriangleThreePoints

myHull :: Hull Int R
myHull = H . map (toTri myPts) $ [ Three 1 2 3
                                 , Three 2 3 4
                                 , Three 0 1 2
                                 , Three 0 2 4
                                 ]

myPts' :: NonEmpty (Point 3 R :+ Int)
myPts' = NonEmpty.fromList $ [ Point3 5  5  0  :+ 2
                             , Point3 1  1  10 :+ 1
                             , Point3 0  10 20 :+ 0
                             , Point3 12 1  1  :+ 3
                             ]

myHull' :: Hull Int R
myHull' = H . map (toTri myPts') $ [ Three 1 2 3
                                   , Three 0 1 2
                                   , Three 0 2 3
                                   ]


--------------------------------------------------------------------------------

-- | Generates a set of n elements (all being different), using the
-- given generator.
setOf    :: Ord a => Int -> Gen a -> Gen (Set.Set a)
setOf n g = buildSet mempty <$> do sz <- getSize
                                   infiniteListOf (resize (max sz n) g)
  where
    buildSet s (x:xs) | length s == n = s
                      | otherwise     = let s' = Set.insert x s in buildSet s' xs
    buildSet _  _                     = error "setOf: absurd"


--------------------------------------------------------------------------------
-- * Some difficult point sets

buggyPoints :: NonEmpty (Point 3 R :+ Int)
buggyPoints = fmap (bimap (10 *^) id) . NonEmpty.fromList $ [Point3 (-7) 2    4    :+ 0
                                                            ,Point3 (-4) 7    (-5) :+ 1
                                                            ,Point3 0    (-7) (-2) :+ 2
                                                            ,Point3 2    (-7) 0    :+ 3
                                                            ,Point3 2    (-6) (-2) :+ 4
                                                            ,Point3 2    5    4    :+ 5
                                                            ,Point3 5    (-1) 2    :+ 6
                                                            ,Point3 6    6    6    :+ 7
                                                            ,Point3 7    (-5) (-6) :+ 8
                                                            ]

buggyPoints2 :: NonEmpty (Point 3 R :+ Int)
buggyPoints2 = fmap (bimap (10 *^) id) . NonEmpty.fromList $ [ Point3 (-5) (-3) 4 :+ 0
                                                             , Point3 (-5) (-2) 5 :+ 1
                                                             , Point3 (-5) (-1) 4 :+ 2
                                                             , Point3 (0) (2)   2 :+ 3
                                                             , Point3 (1) (-5)  4 :+ 4
                                                             , Point3 (3) (-3)  2 :+ 5
                                                             , Point3 (3) (-1)  1 :+ 6
                                                             ]

buggyPoints3 :: NonEmpty (Point 3 R :+ Int)
buggyPoints3 = fmap (bimap (10 *^) id) . NonEmpty.fromList $ [ Point3 (-9 ) (-9) (  7) :+ 0,
                                                               Point3 (-8 ) (-9) ( -2) :+ 1,
                                                               Point3 (-8 ) (7 ) ( -2) :+ 2,
                                                               Point3 (-6 ) (9 ) ( 7) :+ 3,
                                                               Point3 (-3 ) (-6) ( -8) :+ 4,
                                                               Point3 (-3 ) (4 ) (  1) :+ 5,
                                                               Point3 (-2 ) (-9) ( -9) :+ 6,
                                                               Point3 (1  ) (-3) ( 1) :+ 7,
                                                               Point3 (4  ) (5 ) ( 8) :+ 8,
                                                               Point3 (10 ) (3 ) ( 3) :+ 9
                                                             ]


point3 :: [r] -> Point 3 r
point3 = fromJust . pointFromList

buggyPoints5 :: NonEmpty (Point 3 R :+ Int)
buggyPoints5 = mkBuggy $ buggyPoints5'

mkBuggy = fmap (bimap (10 *^) id) . NonEmpty.fromList

buggyPoints5' :: [Point 3 R :+ Int]
buggyPoints5' = [ point3 [-21,14,-4]   :+ 0
                ,point3 [-16,-15,-14] :+ 1
                ,point3 [-14,12,16]   :+ 2
                ,point3 [-11,-19,-7]  :+ 3
                ,point3 [-9,18,14]    :+ 4
                ,point3 [-7,5,5]      :+ 5
                ,point3 [-6,14,11]    :+ 6
                ,point3 [-3,16,10]    :+ 7
                ,point3 [1,-4,0]      :+ 8
                ,point3 [1,19,14]     :+ 9
                ,point3 [3,4,-7]      :+ 10
                ,point3 [6,-8,22]     :+ 11
                ,point3 [8,6,12]      :+ 12
                ,point3 [12,-2,-17]   :+ 13
                ,point3 [23,-18,14]   :+ 14
                ,point3 [23,-6,-18]   :+ 15
                ]



-- buggyPoints5' :: [Point 3 R :+ Int]
-- buggyPoints5' = [point3 [-21,14,-4]   :+ 0
--                 ,point3 [-16,-15,-14] :+ 1
--                 -- ,point3 [-16,12,-23]  :+ 2
--                 -- ,point3 [-16,15,-6]   :+ 3
--                 ,point3 [-14,12,16]   :+ 4
--                 ,point3 [-11,-19,-7]  :+ 5
--                 ,point3 [-9,18,14]    :+ 6
--                 ,point3 [-7,5,5]      :+ 7
--                 ,point3 [-6,14,11]    :+ 8
--                 -- ,point3 [-6,16,-14]   :+ 9
--                 ,point3 [-3,16,10]    :+ 10
--                 ,point3 [1,-4,0]      :+ 11
--                 ,point3 [1,19,14]     :+ 12
--                 ,point3 [3,4,-7]      :+ 13
--                 ,point3 [6,-8,22]     :+ 14
--                 ,point3 [8,6,12]      :+ 15
--                 ,point3 [12,-2,-17]   :+ 16
--                 -- ,point3 [14,11,1]     :+ 17
--                 -- ,point3 [21,-13,20]   :+ 18
--                 ,point3 [23,-18,14]   :+ 19
--                 ,point3 [23,-6,-18]   :+ 20
--                 -- ,point3 [23,4,-16]    :+ 21
--                 ]


-- subs :: SP Index [Event (RealNumber 10)]
-- subs = simulateLeaf' . NonEmpty.fromList $ [Point3 2    (-7) 0    :+ 3
--                                            ,Point3 2    (-6) (-2) :+ 4
--                                            ,Point3 2    5    4    :+ 5
--                                            ]
