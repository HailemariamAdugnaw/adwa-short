import { useState, useEffect } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import toast from 'react-hot-toast'
import {
  Wallet,
  Building,
  CreditCard,
  Phone,
  FileText,
  Save,
  CheckCircle2,
  Receipt,
  ArrowDownLeft,
  Coins,
  Clock,
  Filter,
} from 'lucide-react'
import {
  useCreatorPortalPayoutAccount,
  useCreatorPortalTransactions,
} from '../../lib/hooks'
import { updateCreatorPortalPayoutAccount, errMsg } from '../../lib/api'
import { formatBirr } from '../../lib/format'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'

export function CreatorFinancials() {
  const [activeTab, setActiveTab] = useState('account') // 'account' | 'transactions'
  const [txFilter, setTxFilter] = useState('') // '' | 'coin_payment' | 'pass_consumption' | 'subscription_consumption'

  const qc = useQueryClient()
  const { data: accountData, isLoading: accountLoading } = useCreatorPortalPayoutAccount()
  const { data: transactions, isLoading: txLoading } = useCreatorPortalTransactions({
    source_type: txFilter || undefined,
  })

  // Account form state
  const [bankName, setBankName] = useState('Commercial Bank of Ethiopia (CBE)')
  const [accountName, setAccountName] = useState('')
  const [accountNumber, setAccountNumber] = useState('')
  const [paymentMethod, setPaymentMethod] = useState('cbe')
  const [mobileMoney, setMobileMoney] = useState('')
  const [taxId, setTaxId] = useState('')

  useEffect(() => {
    if (accountData) {
      setBankName(accountData.bank_name || 'Commercial Bank of Ethiopia (CBE)')
      setAccountName(accountData.bank_account_name || '')
      setAccountNumber(accountData.bank_account_number || '')
      setPaymentMethod(accountData.payment_method || 'cbe')
      setMobileMoney(accountData.mobile_money_number || '')
      setTaxId(accountData.tax_id || '')
    }
  }, [accountData])

  const accountMutation = useMutation({
    mutationFn: (payload) => updateCreatorPortalPayoutAccount(payload),
    onSuccess: () => {
      toast.success('Payout account details updated successfully')
      qc.invalidateQueries({ queryKey: ['creator', 'payout-account'] })
    },
    onError: (err) => toast.error(errMsg(err, 'Failed to update payout details')),
  })

  const onSaveAccount = (e) => {
    e.preventDefault()
    accountMutation.mutate({
      bank_name: bankName.trim() || null,
      bank_account_name: accountName.trim() || null,
      bank_account_number: accountNumber.trim() || null,
      payment_method: paymentMethod,
      mobile_money_number: mobileMoney.trim() || null,
      tax_id: taxId.trim() || null,
    })
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-xl font-bold text-text-primary">Financial & Payout Settings</h1>
          <p className="mt-1 text-xs text-text-secondary">
            Manage your recipient bank details, mobile money numbers, and monitor credited earning transactions.
          </p>
        </div>

        {/* Tab Switcher */}
        <div className="inline-flex rounded-lg border border-border bg-surface-1 p-1">
          <button
            onClick={() => setActiveTab('account')}
            className={`flex items-center gap-2 rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'account'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            <Building className="h-3.5 w-3.5" /> Payout Account
          </button>
          <button
            onClick={() => setActiveTab('transactions')}
            className={`flex items-center gap-2 rounded-md px-3.5 py-1.5 text-xs font-semibold transition-colors ${
              activeTab === 'transactions'
                ? 'bg-accent text-white shadow-sm'
                : 'text-text-muted hover:text-text-primary'
            }`}
          >
            <Receipt className="h-3.5 w-3.5" /> Transaction Ledger
          </button>
        </div>
      </div>

      {activeTab === 'account' ? (
        /* Tab 1: Payout Account Settings */
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="card-surface p-6 lg:col-span-2">
            <div className="mb-4 flex items-center justify-between border-b border-border pb-3">
              <div>
                <h2 className="text-sm font-bold text-text-primary">Disbursement Information</h2>
                <p className="text-xs text-text-muted">Enter verified accounts to receive platform earnings.</p>
              </div>
              <Badge tone="accent">Encrypted Storage</Badge>
            </div>

            {accountLoading ? (
              <div className="flex h-64 items-center justify-center">
                <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
              </div>
            ) : (
              <form onSubmit={onSaveAccount} className="space-y-4">
                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium text-text-secondary">Preferred Payment Method</label>
                    <select
                      value={paymentMethod}
                      onChange={(e) => setPaymentMethod(e.target.value)}
                      className="w-full rounded-lg border border-border bg-surface-2 px-3 py-2 text-xs font-medium text-text-primary focus:border-accent focus:outline-none"
                    >
                      <option value="cbe">Commercial Bank of Ethiopia (CBE) (Recommended)</option>
                      <option value="cbe_birr">CBE Birr (Mobile)</option>
                      <option value="bank_transfer">Other Commercial Bank</option>
                    </select>
                  </div>

                  <Input
                    label="CBE Birr Phone Number (Optional)"
                    value={mobileMoney}
                    onChange={(e) => setMobileMoney(e.target.value)}
                    placeholder="+251911000000"
                    leftIcon={<Phone className="h-4 w-4" />}
                  />
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <Input
                    label="Bank Name"
                    value={bankName}
                    onChange={(e) => setBankName(e.target.value)}
                    placeholder="e.g., Commercial Bank of Ethiopia"
                    leftIcon={<Building className="h-4 w-4" />}
                  />

                  <Input
                    label="Bank Account Holder Full Name"
                    value={accountName}
                    onChange={(e) => setAccountName(e.target.value)}
                    placeholder="Legal name on account"
                    leftIcon={<Building className="h-4 w-4" />}
                  />
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <Input
                    label="Bank Account Number / IBAN"
                    value={accountNumber}
                    onChange={(e) => setAccountNumber(e.target.value)}
                    placeholder="e.g., 1000123456789"
                    leftIcon={<CreditCard className="h-4 w-4" />}
                  />

                  <Input
                    label="Legal Tax Identification Number (TIN)"
                    value={taxId}
                    onChange={(e) => setTaxId(e.target.value)}
                    placeholder="e.g., TIN-1234567890"
                    leftIcon={<FileText className="h-4 w-4" />}
                  />
                </div>

                <div className="pt-2">
                  <Button
                    type="submit"
                    loading={accountMutation.isPending}
                    rightIcon={!accountMutation.isPending ? <Save className="h-4 w-4" /> : undefined}
                  >
                    {accountMutation.isPending ? 'Saving Details…' : 'Save Payout Details'}
                  </Button>
                </div>
              </form>
            )}
          </div>

          {/* Right Info Card */}
          <div className="space-y-4">
            <div className="card-surface p-5 border-l-4 border-l-emerald-500">
              <h3 className="text-xs font-bold text-text-primary uppercase tracking-wider">
                Payout Verification Guidelines
              </h3>
              <ul className="mt-3 space-y-2 text-xs text-text-secondary leading-relaxed">
                <li className="flex items-start gap-2">
                  <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />
                  <span>Ensure your bank account holder name exactly matches your legal agreement.</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />
                  <span>All earnings disbursements are transferred directly from the Adwa Short Central Treasury to your registered Commercial Bank of Ethiopia (CBE) account or CBE Birr wallet.</span>
                </li>
                <li className="flex items-start gap-2">
                  <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0 mt-0.5" />
                  <span>Tax numbers (TIN) are required for statutory reporting and annual withholding slips.</span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      ) : (
        /* Tab 2: Transaction History & Ledger */
        <div className="card-surface overflow-hidden">
          <div className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between border-b border-border bg-surface-2/40">
            <div>
              <h2 className="text-sm font-bold text-text-primary">Earnings Transaction Ledger</h2>
              <p className="text-xs text-text-muted">Itemized credits from coin unlocks and prorated pass views.</p>
            </div>

            {/* Filter */}
            <div className="flex items-center gap-2">
              <Filter className="h-3.5 w-3.5 text-text-muted" />
              <select
                value={txFilter}
                onChange={(e) => setTxFilter(e.target.value)}
                className="rounded-lg border border-border bg-surface-1 px-3 py-1.5 text-xs font-medium text-text-primary focus:border-accent focus:outline-none"
              >
                <option value="">All Sources</option>
                <option value="coin_payment">Coin Payments</option>
                <option value="pass_consumption">Time Pass Proration</option>
                <option value="subscription_consumption">Subscription Proration</option>
              </select>
            </div>
          </div>

          {txLoading ? (
            <div className="flex h-64 items-center justify-center">
              <div className="h-8 w-8 animate-spin rounded-full border-2 border-accent border-t-transparent" />
            </div>
          ) : !transactions || transactions.length === 0 ? (
            <div className="p-12 text-center text-xs text-text-muted">
              <Receipt className="mx-auto h-8 w-8 text-text-muted mb-2" />
              <p className="font-semibold text-text-primary">No transactions recorded</p>
              <p className="mt-1">Earning events will appear here as users watch your content.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-border bg-surface-2/60 text-[10px] font-semibold uppercase tracking-wider text-text-muted">
                  <tr>
                    <th className="px-4 py-3.5">Date & Time</th>
                    <th className="px-3 py-3.5">Source Type</th>
                    <th className="px-3 py-3.5">Associated Content</th>
                    <th className="px-3 py-3.5">Reference ID</th>
                    <th className="px-3 py-3.5 text-right">Gross Birr</th>
                    <th className="px-4 py-3.5 text-right font-bold text-emerald-400">Creator Net Birr</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/60">
                  {transactions.map((tx) => (
                    <tr key={tx.id} className="hover:bg-surface-2/30 transition-colors">
                      <td className="px-4 py-3 font-mono text-[11px] text-text-muted">
                        {tx.created_at ? new Date(tx.created_at).toLocaleString() : 'N/A'}
                      </td>
                      <td className="px-3 py-3">
                        <Badge
                          tone={
                            tx.source_type === 'coin_payment'
                              ? 'accent'
                              : tx.source_type === 'pass_consumption'
                              ? 'warning'
                              : 'neutral'
                          }
                        >
                          {tx.source_type.replace(/_/g, ' ')}
                        </Badge>
                      </td>
                      <td className="px-3 py-3">
                        <div>
                          <p className="font-semibold text-text-primary truncate max-w-[200px]">
                            {tx.episode_title || tx.series_title || 'Platform Stream'}
                          </p>
                          {tx.episode_title && tx.series_title && (
                            <p className="text-[10px] text-text-muted truncate max-w-[200px]">
                              {tx.series_title}
                            </p>
                          )}
                        </div>
                      </td>
                      <td className="px-3 py-3 font-mono text-[10px] text-text-muted truncate max-w-[160px]">
                        {tx.reference || `tx-${tx.id}`}
                      </td>
                      <td className="px-3 py-3 text-right font-mono text-text-muted">
                        {formatBirr(tx.gross_amount_birr)}
                      </td>
                      <td className="px-4 py-3 text-right font-mono font-bold text-emerald-400">
                        +{formatBirr(tx.creator_share_birr)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
