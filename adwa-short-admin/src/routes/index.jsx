import { createBrowserRouter, Navigate } from 'react-router-dom'
import { AdminLayout } from '../components/layout/AdminLayout'
import { Login } from '../pages/Login'
import { Dashboard } from '../pages/Dashboard'
import { NotFound } from '../pages/NotFound'
import { SeriesList } from '../pages/content/SeriesList'
import { SeriesCreate } from '../pages/content/SeriesCreate'
import { SeriesEdit } from '../pages/content/SeriesEdit'
import { Episodes } from '../pages/content/Episodes'
import { Categories } from '../pages/categories/Categories'
import { CoinPackages } from '../pages/monetization/CoinPackages'
import { TimePasses } from '../pages/monetization/TimePasses'
import { Subscriptions } from '../pages/monetization/Subscriptions'
import { AdUnlockRule as AdUnlockRulePage } from '../pages/monetization/AdUnlockRule'
import { LoyaltyConfig as LoyaltyConfigPage } from '../pages/monetization/LoyaltyConfig'
import { UsersList } from '../pages/users/UsersList'
import { UserDetail } from '../pages/users/UserDetail'
import { ManualDeposit } from '../pages/walkin/ManualDeposit'
import { Settings as SettingsPage } from '../pages/settings/Settings'
import { ContentPerformance } from '../pages/analytics/ContentPerformance'
import { CreatorsList } from '../pages/creators/CreatorsList'
import { CreatorCreate } from '../pages/creators/CreatorCreate'
import { CreatorDetail } from '../pages/creators/CreatorDetail'
import { SplitConfig } from '../pages/creators/SplitConfig'
import { RevenueOverview } from '../pages/revenue/RevenueOverview'
import { RevenueByCreator } from '../pages/revenue/RevenueByCreator'
import { RevenueByContent } from '../pages/revenue/RevenueByContent'
import { Transactions } from '../pages/revenue/Transactions'
import { Reviews } from '../pages/reviews/Reviews'

export const router = createBrowserRouter([
  { path: '/login', element: <Login /> },
  {
    path: '/',
    element: <AdminLayout />,
    children: [
      { index: true, element: <Dashboard /> },
      { path: 'content/series', element: <SeriesList /> },
      { path: 'content/series/new', element: <SeriesCreate /> },
      { path: 'content/series/:id/edit', element: <SeriesEdit /> },
      { path: 'content/episodes', element: <Episodes /> },
      { path: 'categories', element: <Categories /> },
      { path: 'monetization/coins', element: <CoinPackages /> },
      { path: 'monetization/passes', element: <TimePasses /> },
      { path: 'monetization/subscriptions', element: <Subscriptions /> },
      { path: 'monetization/ad-unlock', element: <AdUnlockRulePage /> },
      { path: 'monetization/loyalty', element: <LoyaltyConfigPage /> },
      { path: 'creators', element: <CreatorsList /> },
      { path: 'creators/new', element: <CreatorCreate /> },
      { path: 'creators/:id', element: <CreatorDetail /> },
      { path: 'creators/:id/split', element: <SplitConfig /> },
      { path: 'revenue', element: <RevenueOverview /> },
      { path: 'revenue/by-creator', element: <RevenueByCreator /> },
      { path: 'revenue/by-content', element: <RevenueByContent /> },
      { path: 'revenue/transactions', element: <Transactions /> },
      { path: 'reviews', element: <Reviews /> },
      { path: 'users', element: <UsersList /> },
      { path: 'users/:id', element: <UserDetail /> },
      { path: 'walkin/manual-deposit', element: <ManualDeposit /> },
      { path: 'analytics/content', element: <ContentPerformance /> },
      { path: 'settings', element: <SettingsPage /> },
    ],
  },
  { path: '/404', element: <NotFound /> },
  { path: '*', element: <Navigate to="/404" replace /> },
])
