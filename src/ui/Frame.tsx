import type { ReactNode } from 'react'

export function Frame({
  kicker,
  title,
  lede,
  onBack,
  children,
  footer,
}: {
  kicker?: string
  title: string
  lede?: string
  onBack?: () => void
  children: ReactNode
  footer?: ReactNode
}) {
  return (
    <div className="app">
      <header className="topbar">
        <p className="brand">CODAG.0</p>
        {onBack ? (
          <button className="ghost" type="button" onClick={onBack}>
            Back
          </button>
        ) : (
          <span />
        )}
      </header>
      <main className="panel">
        {kicker ? <p className="kicker">{kicker}</p> : null}
        <h1>{title}</h1>
        {lede ? <p className="lede">{lede}</p> : null}
        {children}
        {footer ? <div className="footer-actions">{footer}</div> : null}
      </main>
    </div>
  )
}
