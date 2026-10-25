import { createBrowserRouter, Navigate } from 'react-router-dom'
import { AdminLayout } from '../components/layout/AdminLayout'
import { Login } from '../pages/Login'
import { ForgotPassword } from '../pages/auth/ForgotPassword'
import { ResetPassword } from '../pages/auth/ResetPassword'
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
import { StaffManagement } from '../pages/staff/StaffManagement'
import { StaffActivityLog } from '../pages/staff/StaffActivityLog'
import { CreatorDashboard } from '../pages/creator/CreatorDashboard'
import { CreatorContent } from '../pages/creator/CreatorContent'
import { CreatorReviews } from '../pages/creator/CreatorReviews'
import { CreatorFinancials } from '../pages/creator/CreatorFinancials'
import { CreatorProfile } from '../pages/creator/CreatorProfile'
import { SuperAdminRoute } from '../components/layout/SuperAdminRoute'
import { CreatorRoute } from '../components/layout/CreatorRoute'

export const router = createBrowserRouter([
  { path: '/login', element: <Login /> },
  { path: '/forgot-password', element: <ForgotPassword /> },
  { path: '/reset-password', element: <ResetPassword /> },
  {
    path: '/',
    element: <AdminLayout />,
    children: [
      { index: true, element: <SuperAdminRoute><Dashboard /></SuperAdminRoute> },
      { path: 'content/series', element: <SeriesList /> },
      { path: 'content/series/new', element: <SeriesCreate /> },
      { path: 'content/series/:id/edit', element: <SeriesEdit /> },
      { path: 'content/episodes', element: <Episodes /> },
      { path: 'categories', element: <Categories /> },
      { path: 'monetization/coins', element: <SuperAdminRoute><CoinPackages /></SuperAdminRoute> },
      { path: 'monetization/passes', element: <SuperAdminRoute><TimePasses /></SuperAdminRoute> },
      { path: 'monetization/subscriptions', element: <SuperAdminRoute><Subscriptions /></SuperAdminRoute> },
      { path: 'monetization/ad-unlock', element: <SuperAdminRoute><AdUnlockRulePage /></SuperAdminRoute> },
      { path: 'monetization/loyalty', element: <SuperAdminRoute><LoyaltyConfigPage /></SuperAdminRoute> },
      { path: 'creators', element: <SuperAdminRoute><CreatorsList /></SuperAdminRoute> },
      { path: 'creators/new', element: <SuperAdminRoute><CreatorCreate /></SuperAdminRoute> },
      { path: 'creators/:id', element: <SuperAdminRoute><CreatorDetail /></SuperAdminRoute> },
      { path: 'creators/:id/split', element: <SuperAdminRoute><SplitConfig /></SuperAdminRoute> },
      { path: 'revenue', element: <SuperAdminRoute><RevenueOverview /></SuperAdminRoute> },
      { path: 'revenue/by-creator', element: <SuperAdminRoute><RevenueByCreator /></SuperAdminRoute> },
      { path: 'revenue/by-content', element: <SuperAdminRoute><RevenueByContent /></SuperAdminRoute> },
      { path: 'revenue/transactions', element: <SuperAdminRoute><Transactions /></SuperAdminRoute> },
      { path: 'reviews', element: <SuperAdminRoute><Reviews /></SuperAdminRoute> },
      { path: 'users', element: <SuperAdminRoute><UsersList /></SuperAdminRoute> },
      { path: 'users/:id', element: <SuperAdminRoute><UserDetail /></SuperAdminRoute> },
      { path: 'walkin/manual-deposit', element: <SuperAdminRoute><ManualDeposit /></SuperAdminRoute> },
      { path: 'analytics/content', element: <SuperAdminRoute><ContentPerformance /></SuperAdminRoute> },
      { path: 'staff', element: <SuperAdminRoute><StaffManagement /></SuperAdminRoute> },
      { path: 'staff/activity', element: <SuperAdminRoute><StaffActivityLog /></SuperAdminRoute> },
      { path: 'creator/dashboard', element: <CreatorRoute><CreatorDashboard /></CreatorRoute> },
      { path: 'creator/content', element: <CreatorRoute><CreatorContent /></CreatorRoute> },
      { path: 'creator/reviews', element: <CreatorRoute><CreatorReviews /></CreatorRoute> },
      { path: 'creator/financials', element: <CreatorRoute><CreatorFinancials /></CreatorRoute> },
      { path: 'creator/profile', element: <CreatorRoute><CreatorProfile /></CreatorRoute> },
      { path: 'settings', element: <SuperAdminRoute><SettingsPage /></SuperAdminRoute> },
    ],
  },
  { path: '/404', element: <NotFound /> },
  { path: '*', element: <Navigate to="/404" replace /> },
])
