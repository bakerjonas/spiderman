--
-- (c) jonas.juselius@uit.no, 2013
--
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

-- | Generate HTML from Lmod(ualtor) Packages using HStringTemplates.
module SoftwarePages (
      Page(..) 
    , renderPackageListingPage
    , renderVersionPage
    , renderHelpPage
    , formatPackageList
    , sortPackages
    , addGititHeaders
    , urlify
    , rstToHtml
    , htmlToRst
    , packageVersionUrl
    , packageHelpUrl
    , packageVersionFileName
    ) where

import Control.Applicative
import Control.Monad
import Data.List
import Data.Char
import Data.Function (on)
import Text.Regex.Posix
import Text.Blaze.Html.Renderer.Pretty (renderHtml)
import Text.Hamlet (hamlet, hamletFile, HtmlUrl)
import qualified Text.Pandoc as P
import qualified Data.Text as T
import qualified Data.HashMap.Strict as HM
import LmodPackage 
import Paths_spiderman

data Page = Page
    { pageTitle :: T.Text
    , pageFile :: T.Text -> T.Text
    , pagePackage :: Package
    }

data Route = Home
    | Base
    | BaseCss
    | PrintCss
    | Images

renderUrl :: Route -> [(T.Text, T.Text)] -> T.Text
renderUrl Home _ = "/"
renderUrl Base _ = "/software"
renderUrl BaseCss _ = "/css/custom.css"
renderUrl PrintCss _ = "/css/print.css"
renderUrl Images _ = "/img"

formatPackageList :: Page -> [Package] -> [Page]
formatPackageList stencil [] = [stencil { pagePackage = emptyPackage }]
formatPackageList stencil pkgs = 
    map (\p -> formatPackage stencil { pagePackage = p }) pkgs

formatPackage :: Page -> Page
formatPackage page = page { pagePackage  = p
    { moduleName = trimPackageName . packageName $ p
--     , description = T.take 80 . description $ p
    , defaultVersion = formatVersion page defaultVersion
    , versionPageUrl = pageFile page $ packageVersionUrl p 
    , category  = T.toLower . category $ p
    , keywords = map T.toLower $ keywords p 
    , versions = HM.map (formatVersion page) $ versions p
    }}
    where 
        p = pagePackage page
        defaultVersion = getDefaultVersion p 
    
formatVersion page v = v 
    { helpText = T.pack . rstToHtml . T.unpack . helpText $ v
    , helpPageHref = if url == "" 
        then ""
        else "href=\"" `T.append` url `T.append` "\""
    } 
    where 
        url = packageHelpUrl page v 

trimPackageName pkg =
    let p = T.takeWhile (/='/') . T.reverse $ pkg in
        if p == T.empty then "" else T.reverse p

-- | Remove first part of a package path, up until first '/' 
cleanPath x 
    | T.any (=='/') x = T.tail . T.dropWhile (/='/') $ x
    | otherwise = x

addGititHeaders p = "---\ntoc: no\ntitle:\n...\n\n" `T.append` p

-- | Convert a package/version path to a usable url name
urlify = T.toLower . T.replace "/" "." 

rstToHtml =  P.writeHtmlString P.def . P.readRST P.def 

htmlToRst =  T.pack . P.writeRST P.def . P.readHtml P.def . T.unpack

sortPackages = sortBy (compare `on` T.toLower . displayName)  

tabs = "This is a tab" :: T.Text

pageTemplate :: T.Text -> HtmlUrl Route -> HtmlUrl Route
pageTemplate title content = $(hamletFile "templates/page.hamlet")
-- packagesTemplate = $(hamletFile "templates/packages.hamlet")
-- helpTemplate = $(hamletFile "templates/help.hamlet")
-- versionsTemplate = $(hamletFile "templates/versions.hamlet")

logo = $(hamletFile "templates/logo.hamlet")
footer = $(hamletFile "templates/footer.hamlet")

header :: T.Text -> HtmlUrl Route
header title = $(hamletFile "templates/header.hamlet")

sitenav = $(hamletFile "templates/sitenav.hamlet")

renderPackageListingPage pages = 
    T.pack . renderHtml $ pageTemplate "foop" logo $ renderUrl
    where 
        title = pageTitle (head pages)
        packages = map pagePackage pages
    
renderVersionPage page = 
    T.pack "version"
--     renderHtml $ versionsTemplate renderUrl
    where 
        package = pagePackage page
        title = ("Package " `T.append` packageName package) 
        ver = (versions package) 
        keys = (keywords package)
--         ext = (pageExt page)  
--     setAttribute "pagetitle" ("Package " `T.append` package p) 
--     $ setAttribute "versions" (versions p) 
--     $ setAttribute "keywords" (keywords p)
--     $ setAttribute "package" (pkg page)  
--     $ setAttribute "ext" (ext page)  
--     $ templ
--     where 
--         templ = mainTemplate page
--         p = pkg page

renderHelpPage page v = 
    "help"
--     renderHtml $ helpTemplate renderUrl
    where
        pagetitle = ("Module " `T.append` fullName v) 
        helptext = (helpText v) 
        package = (pagePackage page)  
--         ext = (pageExt page)  
--     setAttribute "pagetitle" ("Module " `T.append` fullName v) 
--     $ setAttribute "helptext" (helpText v) 
--     $ setAttribute "package" (pkg page)  
--     $ setAttribute "ext" (ext page)  
--     $ templ
--     where 
--         templ = mainTemplate page

packageVersionUrl p = urlify (packageName p)

packageHelpUrl page v = 
    let (a, b, c, g) = t =~ pat :: (String, String, String, [String]) in
    case g of
        [s, u] -> if s == "Site" then T.pack u else ""  
        [s, a1, u, a2] -> if s == "Site" then T.pack u else ""  
        -- return url to help page to be generated
        [] -> pageFile page $ fullName v
    where 
        t = T.unpack . helpText $ v
        pat = "(Site|Off-site) help:" ++ 
            "*(<a .*>)* *(http://[^ \t]*) *(</a>)*$" :: String

-- packageHelpUrl v = 
--     let (a, b, c , d) = helpText v =~ "See  *(http://[^ \t]*)" :: 
--         (String,String,String,[String]) in
--     urlify (fullName v)

packageVersionFileName page = 
    T.unpack . pageFile page $ packageName p
    where p = pagePackage page

