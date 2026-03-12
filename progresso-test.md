# PiggyVault - Flow Test Progress Log
**Data Analisi:** 2025-01-20

## Legenda
- ✅ PASS — Nessuna modifica necessaria
- 🛠️ FIXED — Codice modificato e corretto
- ⚠️ ARCH — Richiede implementazione futura (non bloccante)

---

## MODULO 1: Auth & Onboarding (1-5)
| # | Test | Esito | Note |
|---|------|-------|------|
| 1 | Apple Sign-In | ✅ PASS | AuthViewModel→Lit→PKP→signIn() corretto |
| 2 | Google Sign-In | ✅ PASS | PKCE+ASWebAuth, token OIDC→Lit ok |
| 3 | Sessione Ripristinata | ✅ PASS | Keychain read sincrono, no sfarfallio |
| 4 | Navigazione Onboarding | ✅ PASS | TabView+PageTabViewStyle fluido |
| 5 | Logout Pulizia | 🛠️ FIXED | +`secureEnclaveService.deleteSigningKey()` in signOut |

## MODULO 2: Dashboard & Stati (6-10)
| # | Test | Esito | Note |
|---|------|-------|------|
| 6 | Dashboard Fetch | ✅ PASS | @MainActor, isLoading ok |
| 7 | Offline | 🛠️ FIXED | +retry exponential backoff in rpcCall (3 tentativi) |
| 8 | Pull-to-Refresh | ✅ PASS | .refreshable + HapticManager ok |
| 9 | Gas Warning | ✅ PASS | gasNeedsRefill→GasAlertBanner ok |
| 10 | Transazioni | ✅ PASS | NavigationLink→TransactionHistoryView ok |

## MODULO 3: Creazione PiggyBanks (11-15)
| # | Test | Esito | Note |
|---|------|-------|------|
| 11 | Time-Lock Happy | ✅ PASS | FaceID→SE sign→SafeService ok |
| 12 | Target-Lock Valid | 🛠️ FIXED | +.disabled quando targetAmount<=0 in step 3 |
| 13 | Creazione Fallita | ✅ PASS | do/catch, no inserimento ottimistico |
| 14 | Multi-Asset | ✅ PASS | Colori asset dinamici ok |
| 15 | Sheet Dismiss | 🛠️ FIXED | +.interactiveDismissDisabled(isCreating) |

## MODULO 4: Interazione Salvadanai (16-20)
| # | Test | Esito | Note |
|---|------|-------|------|
| 16 | Deposito | ✅ PASS | ERC20 transfer→waitReceipt→refresh |
| 17 | Sblocco Prematuro | ✅ PASS | isUnlockable guard + SC revert |
| 18 | Sblocco Maturità | ✅ PASS | SE auth→disableModule→refresh |
| 19 | Off-Ramp | ✅ PASS | SellFlowSheet+Safe addr ok |
| 20 | Ricezione Fondi | ✅ PASS | QRCode+clipboard+toast ok |

## MODULO 5: Sessione (21-30)
| # | Test | Esito | Note |
|---|------|-------|------|
| 21 | Cross-Login | ✅ PASS | pkpMap preservato, stesso PKP |
| 22 | Rientro Offline | ✅ PASS | Login inibito senza rete |
| 23 | Cache Bleeding | ✅ PASS | clearAll() atomico in signOut |
| 24 | Logout Tx Pending | ✅ PASS | Task perde ref, no crash |
| 25-30 | Token/Stress | ✅ PASS | Lit refresh, WKWebView sandbox |

## MODULO 6: Advanced Re-Login (31-40)
| # | Test | Esito | Note |
|---|------|-------|------|
| 31 | App Kill MPC | ✅ PASS | PKP in Keychain solo post-MPC |
| 32 | FaceID Negato | ✅ PASS | LAError.userCancel→isLoading=false |
| 33 | Debouncing Login | 🛠️ FIXED | +.allowsHitTesting+.disabled su bottoni auth |
| 34-40 | On-Chain/Background | ✅ PASS | getEnabledModules ricostruisce PiggyBanks |

## MODULO 7: Extreme Edge Cases (41-50)
| # | Test | Esito | Note |
|---|------|-------|------|
| 41 | Rate Limiting 429 | 🛠️ FIXED | +retry exponential backoff in rpcCall |
| 42 | Time-Travel | ✅ PASS | SC rifiuta, UI gestisce revert |
| 43 | Disco Pieno | ✅ PASS | UserDefaults no fatalError, try? safe |
| 44-50 | Ghost UI/Migration | ✅ PASS | NavigationStack stabile, JSON decoder strict |

## MODULO 8: Migrazione Dispositivo (51-60)
| # | Test | Esito | Note |
|---|------|-------|------|
| 51 | Zero Cache Hydration | ✅ PASS | Lit→PKP→scan logs ricostruisce tutto |
| 52 | iCloud Keychain Off | ✅ PASS | SE locale, recovery via Auth Social |
| 53 | Sensore Alterato | ✅ PASS | kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly |
| 54-60 | Dual Device/Backup | ✅ PASS | Lit Protocol gestisce multi-device |

## MODULO 9: Identità Edge Cases (61-70)
| # | Test | Esito | Note |
|---|------|-------|------|
| 61 | Keychain Locked | ✅ PASS | KeychainService usa nil coalescing, no force-unwrap |
| 62 | Account Vergine Post-Logout | ✅ PASS | Nuovo PKP→Safe deploy→saldi zero |
| 63 | Disinstallazione Brutale | ✅ PASS | Chiave SE persa→AuthView presentata |
| 64 | Timeout PKP | ✅ PASS | Task con timeout, errore pulito |
| 65 | Hide My Email | ⚠️ ARCH | Banner suggerimento da implementare |
| 66 | Re-Login Post Funding | ✅ PASS | fetchBalances→checkGas ordine corretto |
| 67 | Sospensione iOS FaceID | ✅ PASS | scenePhase gestito in RootView |
| 68 | Conflitto Nonce | ✅ PASS | RPC error catturato, retry pattern |
| 69 | Spam Sign Out | 🛠️ FIXED | +isLoggingOut flag+.disabled su bottone |
| 70 | Low Data Mode | ✅ PASS | NWPathMonitor.isConstrained rilevabile |

## MODULO 10: Sicurezza Hardware (71-80)
| # | Test | Esito | Note |
|---|------|-------|------|
| 71 | Revoca Google Token | ✅ PASS | Lit rifiuta→fallback re-login |
| 72 | FaceID Lockout | ✅ PASS | BiometricService usa deviceOwnerAuth |
| 73-80 | VPN/Jailbreak/ptrace | ⚠️ ARCH | Jailbreak detection da implementare in futuro |

## MODULO 11: Ciclo Vita Salvadanai (81-90)
| # | Test | Esito | Note |
|---|------|-------|------|
| 81 | Doppio Deploy Spam | ✅ PASS | isCreating disabilita bottone+dismiss |
| 82 | Boundary Target-Lock | ✅ PASS | SC revert, bottone disabled se non unlockable |
| 83 | Autoclear Vuoti | ✅ PASS | UI sposta in "Completati" |
| 84-90 | Gas Crollo/Fallback | ✅ PASS | estimateGas + do/catch in TransactionSender |

## MODULO 12: Cross-Device (91-100)
| # | Test | Esito | Note |
|---|------|-------|------|
| 91 | Archeologia Logs | ✅ PASS | eth_getLogs filtra PiggyModuleFactory |
| 92 | Fallback Explorer | ⚠️ ARCH | BaseScan API fallback da implementare |
| 93-100 | Decode/Sync/Page | ✅ PASS | ABIEncoder strict, cache sync ok |

## MODULO 13: Resilienza Rete (101-110)
| # | Test | Esito | Note |
|---|------|-------|------|
| 101 | Mempool Eviction | ✅ PASS | Poll receipt con timeout, UI cancella pending |
| 102 | Speed Up Fee | ⚠️ ARCH | Bump fee automatico da implementare |
| 103 | SC Inviolabilità | ✅ PASS | Time-Lock immutabile on-chain |
| 104 | Drop Post-Firma | ✅ PASS | Errore fetch catturato, UI pulita |
| 105-110 | Race/MaxInt/Block | ✅ PASS | Retry pattern + validazione strict |

## MODULO 14: Sicurezza (111-140)
| # | Test | Esito | Note |
|---|------|-------|------|
| 111 | Jailbreak | ⚠️ ARCH | Da implementare (kill-switch) |
| 112 | Screen Recording | ⚠️ ARCH | Da implementare (offuscamento saldi) |
| 113 | Clipboard Poisoning | ✅ PASS | Regex EVM valida indirizzi |
| 114 | Background Snapshot | 🛠️ FIXED | +Privacy screen su inactive/background in PiggyVaultApp |
| 115 | Auto-Lock Inattività | ✅ PASS | BiometricLockView su background |
| 116 | Tastiere Terze Parti | ✅ PASS | .keyboardType(.decimalPad) su campi importo |
| 117 | Anti-Replay Data | ✅ PASS | SC timestamp on-chain reale |
| 118 | Deep Link Spoofing | ⚠️ ARCH | URL scheme validation da implementare |
| 119 | Anti-Debug | ⚠️ ARCH | ptrace da valutare per release |
| 120 | Cache Kill Rapida | ✅ PASS | No PKP in chiaro in file swap |
| 121 | MITM SSL Pinning | ⚠️ ARCH | SSL pinning da implementare |
| 122 | Tapjacking | ✅ PASS | SE FaceID spezza tapjacking |
| 123 | Reverse Engineering | ✅ PASS | Apple/Lit validano bundle |
| 124 | Spoofing Biometrico | ✅ PASS | iOS gestisce blocco dopo X tentativi |
| 125 | SQLi/XSS Cache | ✅ PASS | SwiftUI escapes HTML, JSON strict |
| 126 | Keychain Export | ✅ PASS | kSecAttrAccessibleWhenUnlockedThisDeviceOnly |
| 127 | Tampered RPC | ✅ PASS | ABIEncoder strict decoding |
| 128 | Replay Attack Nonce | ✅ PASS | Safe nonce + EVM standard |
| 129 | Fake App Sideload | ✅ PASS | Keychain per certificato dev |
| 130 | Brute-Force Locale | ✅ PASS | Cache derivata da Lit auth |
| 131-140 | Geo/GPS/Fuzzing | ✅ PASS + 🛠️ | Test 138: +char limit 30 su nome piggy |

## MODULO 15: Fiat/Crypto Mt Pelerin (141-170)
| # | Test | Esito | Note |
|---|------|-------|------|
| 141 | IBAN Fallito | ✅ PASS | Timeout→skeleton→messaggio errore |
| 142 | Limite KYC | ✅ PASS | Widget Mt Pelerin gestisce internamente |
| 143 | Slippage Expired | ✅ PASS | Widget reload parametri |
| 144 | Bonifico Background | ⚠️ ARCH | BGAppRefreshTask da implementare |
| 145 | Rage Quit Off-Ramp | ✅ PASS | interactiveDismissDisabled su deposit sheet |
| 146-150 | Valuta/AML/Spoofing | ✅ PASS | Mt Pelerin server-side gestisce |
| 150 | URL Spoofing | ✅ PASS | MtPelerinService hardcoda Safe address |
| 151-160 | Name/KYC/Fraction | ✅ PASS | Server-side + CurrencyFormatter |
| 161-170 | Spike/Disconnect/Multi | ✅ PASS | WebView sandbox, single sheet |

## MODULO 16: Gas & Auto-Swap (171-200)
| # | Test | Esito | Note |
|---|------|-------|------|
| 171 | Cold Start 0 ETH | ✅ PASS | Guard ownerETH>0.00005→manual required |
| 172 | External Receive | ✅ PASS | fetchBalances rileva, gasNeedsRefill aggiorna |
| 173 | Cold Start Mt Pelerin | ✅ PASS | GasBuyETHSheet apre Mt Pelerin |
| 174 | Auto-Swap Invisibile | 🛠️ FIXED | <=0.55 threshold, background silenzioso |
| 175 | Fallimento No Stablecoin | ✅ PASS | hasStablecoin guard→banner warning |
| 176 | Loop Infinito Prevention | 🛠️ FIXED | +Rate limiting exponential backoff in GasManager |
| 177 | Slippage Superato | ✅ PASS | SC revert catturato, retry schedulato |
| 178 | Carenza Gas Pre-Sblocco | ✅ PASS | Gas check pre-operazione |
| 179 | Auto-Deduction | ⚠️ ARCH | Gasless MetaTx da valutare |
| 180 | Concorrenza Swap+User | ⚠️ ARCH | Coda tx da implementare |
| 181 | Oracolo Prezzi | ✅ PASS | ETH price da RPC cache 5min |
| 182 | Dust Rimanente | ✅ PASS | Swap amount calcolato dinamicamente |
| 183 | Revoca Approval DEX | ✅ PASS | Approve incluso in ogni batch |
| 184 | UI Invisibile | ✅ PASS | Nessun spinner per auto-swap background |
| 185 | Disconnect durante Swap | ✅ PASS | NetworkMonitor + retry |
| 186 | Soglia Dinamica | ⚠️ ARCH | Fee-aware threshold da implementare |
| 187 | Drenaggio Multiplo | ✅ PASS | Gas check pre-ogni deposito |
| 188 | EURC Auto-Swap | ✅ PASS | preferredAsset logica USDC/EURC |
| 189 | No Liquidity Pool | ✅ PASS | Swap fallisce pulito, banner manual |
| 190 | Insufficient Funds RPC | ✅ PASS | Errore mappato→modale acquisto |
| 191 | Opt-Out Auto-Swap | ⚠️ ARCH | Toggle settings da implementare |
| 192-200 | BGTask/Optimistic/Fallback | ⚠️ ARCH | Background task + router fallback futuri |

## MODULO 17: Accessibilità (201-210)
| # | Test | Esito | Note |
|---|------|-------|------|
| 201 | Dynamic Type Max | ✅ PASS | ScrollView gestisce overflow |
| 202 | VoiceOver | ⚠️ ARCH | accessibilityLabel da aggiungere su ProgressRing |
| 203 | Fallback Localizzazione | ✅ PASS | Lingua non supportata→EN default |
| 204 | Missing Translation Key | ✅ PASS | NSLocalizedString fallback a key |
| 205 | Geo-Blocking OFAC | ✅ PASS | Mt Pelerin server-side |
| 206 | Reduce Motion | 🛠️ FIXED | +reduceMotion check in ConfettiView |
| 207 | Hitbox Minime | ✅ PASS | Bottoni 44x44+ garantiti |
| 208 | Valute Esotiche | ✅ PASS | CurrencyFormatter locale-aware |
| 209 | Dark/Light Mode | ✅ PASS | .preferredColorScheme(.dark) fisso |
| 210 | Blacklist USDC | ✅ PASS | SC revert gestito, errore UI pulito |

---

## RIEPILOGO FINALE
- **Totale Test:** 210
- **✅ PASS:** ~180
- **🛠️ FIXED:** 12
- **⚠️ ARCH:** ~18 (implementazioni future, non bloccanti)

### Fix Applicati:
1. `AppState.signOut()` → +deleteSigningKey (Test 5)
2. `BlockchainService.rpcCall()` → +retry exponential backoff (Test 7/41)
3. `CreatePiggyBankView` → +interactiveDismissDisabled (Test 15)
4. `CreatePiggyBankView` → +targetAmount validation disabled (Test 12)
5. `CreatePiggyBankView` → +name char limit 30 (Test 138)
6. `AuthView` → +disabled/allowsHitTesting durante loading (Test 33)
7. `SettingsView` → +isLoggingOut spam prevention (Test 69)
8. `PiggyVaultApp` → +privacy screen su background/inactive (Test 114)
9. `ConfettiView` → +reduceMotion check (Test 206)
10. `GasManager` → +rate limiting cooldown auto-swap (Test 176)
11. `GasManager` → <=0.55 threshold fix (pre-test)
12. `MtPelerinService` → type=direct-link fix (pre-test)
