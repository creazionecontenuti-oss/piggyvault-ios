---
trigger: manual
---

# PiggyVault - Flow Tests & AI Static Analysis Scenarios

## Regola AI: Esecuzione Autonoma dei Flow Tests e Static Analysis

Descrizione: Questa regola imposta l'AI in modalità "Agent" completamente autonoma per la validazione statica, il fix del codice e il tracciamento dei flussi definiti in questa rule.

🤖 Istruzioni Operative Core (Zero-Prompting)

### Esecuzione Ricorsiva Continua:

Leggi il documento piggyvault_qa_flows.md.

Inizia l'analisi dal Test 1 e procedi in modo sequenziale fino all'ultimo.

REGOLA D'ORO: NON fermarti per chiedere conferme, approvazioni o direttive all'utente. Esegui il ciclo in maniera totalmente ricorsiva e silenziosa.

### Fix Autonomo (Auto-Healing):

Per ogni test, esegui una Static Analysis dei file Swift pertinenti (come indicato nel paragrafo "Verifica Codice").

Se l'architettura attuale NON supporta l'Happy Path o non gestisce l'Edge Case richiesto, modifica e correggi il codice in autonomia.

Assicurati che le modifiche rispettino i pattern architetturali (MVVM), l'uso di @MainActor, la gestione concorrente (async/await) e che non introducano regressioni.

### Log di Progresso Obbligatorio (progresso-test.md):

L'AI deve creare (o aggiornare, se esiste già) un file di log nella root del progetto denominato progresso-test.md.

Subito dopo aver analizzato/modificato il codice per un test specifico, l'AI deve appendere un record aggiornato al file usando rigorosamente il seguente template:

### Test [NUMERO]: [NOME DEL TEST]
- **Timestamp:** YYYY-MM-DD HH:MM:SS
- **Esito:** [✅ PASS (Nessuna modifica)] | [🛠️ FIXED (Codice modificato)] | [❌ FAILED (Richiede intervento architetturale grave)]
- **File Analizzati/Toccati:** [Lista dei file, es. `AuthViewModel.swift`, `LitProtocolService.swift`]
- **Note dell'AI:** [Breve spiegazione tecnica di ciò che è stato validato o del fix apportato in autonomia].


### Gestione degli Errori di Compilazione:

Se le tue stesse modifiche introducono un potenziale errore di compilazione deducibile staticamente (es. firme di metodi non corrispondenti, missing return), esegui un self-check e fixalo immediatamente prima di passare al test successivo.

### Fine del Ciclo:

Interrompi il lavoro e avvisa l'utente SOLO in due casi:
- A Hai completato tutti i 110 test.
- B Hai incontrato un blocco di sistema insormontabile che richiede la riscrittura di interi moduli (esito FAILED grave). In tal caso, ferma la ricorsione e chiedi come procedere esponendo il problema.


🟢 MODULO 1: Autenticazione & Onboarding (Flussi 1-5)

Test 1: Nuovo Utente (Apple Sign-In)

Azione: L'utente apre l'app per la prima volta -> Scorrevole Onboarding -> Tap su "Continua con Apple".

Desired Outcome: L'app richiede FaceID -> Genera credenziali -> Chiama LitProtocolService -> Genera PKP -> Mostra Confetti -> Naviga a MainTabView.

Verifica Codice (AI Static Analysis): Controllare AuthViewModel.swift per il routing post-login. Verificare che LitProtocolService chiami correttamente la rete MPC e restituisca una PKP valida prima di aggiornare AppState.

Test 2: Nuovo Utente (Google Sign-In)

Azione: Tap su "Continua con Google".

Desired Outcome: Apre WebView di Google o SFSafariViewController -> Login -> Redirect all'app -> LitProtocolService -> Naviga a MainTabView.

Verifica Codice: Verificare GoogleAuthService.swift e la gestione degli URL Scheme in PiggyVaultApp.swift. Controllare che il token OIDC venga passato correttamente al nodo Lit.

Test 3: Sessione Ripristinata (Utente Esistente)

Azione: L'utente chiude l'app dal multitasking e la riapre.

Desired Outcome: AppState legge il WalletCacheService/KeychainService all'avvio -> Salta Onboarding/Auth -> Entra istantaneamente in DashboardView mostrando la cache in attesa del refresh di rete.

Verifica Codice: Analizzare l'init di AppState.swift e RootView.swift. Assicurarsi che la lettura dal Keychain sia sincrona o risolta nel main thread prima del render iniziale per evitare sfarfallii (Ghost UI).

Test 4: Navigazione Onboarding

Azione: L'utente fa swipe tra le 4 pagine dell'onboarding.

Desired Outcome: Transizioni fluide, cambio del testo sincronizzato, pallini di paginazione aggiornati.

Verifica Codice: Controllare OnboardingView.swift. Verificare l'uso corretto di TabView con PageTabViewStyle e l'assenza di memory leaks nelle immagini/animazioni caricate.

Test 5: Logout e Pulizia Dati

Azione: Utente va in Settings -> Sign Out -> Conferma l'alert.

Desired Outcome: KeychainService cancellato, WalletCacheService svuotato, torna alla prima pagina di AuthView.

Verifica Codice: Controllare la funzione signOut() in SettingsView e AppState. Deve garantire la rimozione sicura di PKP e chiavi enclave.

🔵 MODULO 2: Dashboard & Stati Globali (Flussi 6-10)

Test 6: Happy Path Fetching Dashboard

Azione: Lancio a freddo della Dashboard.

Desired Outcome: Shimmer loading attivo -> BlockchainService fetch saldo Base -> Aggiorna UI -> Nasconde Shimmer.

Verifica Codice: Verificare che DashboardViewModel usi @MainActor per aggiornare la UI e che gli state di caricamento (isLoading) siano ben definiti.

Test 7: Connettività Offline globale

Azione: App avviata in modalità aereo.

Desired Outcome: NetworkMonitor rileva assenza rete -> Mostra GasAlertBanner (o NetworkBanner rosso) -> Carica i dati vecchi da WalletCacheService. Nessuna ruota di caricamento infinita.

Verifica Codice: Controllare NetworkMonitor.swift. Assicurarsi che le chiamate RPC in BlockchainService abbiano un timeout e un fallback catch che non crashi l'app.

Test 8: Pull-to-Refresh

Azione: Swipe down su PiggyBankListView o DashboardView.

Desired Outcome: Haptic feedback "light" -> Rotella di caricamento nativa -> Aggiornamento forzato saldi e lista PiggyBanks.

Verifica Codice: Verificare il modificatore .refreshable { ... } nelle View e l'uso di HapticManager.swift.

Test 9: Warning Gas Insufficiente (Generico UI)

Azione: Lettura saldi restituisce ETH == 0, ma ci sono ERC20.

Desired Outcome: AccountProfileView e DashboardView visualizzano i badge di sistema appropriati (es. "Ricarica Gas") e bloccano le transazioni.

Verifica Codice: Controllare la logica in GasManager.swift e come il booleano hasEnoughGas viene propagato in UI.

Test 10: Navigazione Transazioni

Azione: Tap su "Storico Transazioni".

Desired Outcome: Apre la TransactionHistoryView popolata con dati formattati correttamente da BaseScan o RPC Logs.

Verifica Codice: Verificare i decoder JSON in TransactionHistoryView e il format di CurrencyFormatter.swift.

🟠 MODULO 3: Creazione PiggyBanks / Smart Contracts (Flussi 11-15)

Test 11: Creazione Time-Lock (Happy Path)

Azione: Creazione salvadanaio bloccato per 30 giorni. Tap su Crea.

Desired Outcome: Richiesta FaceID -> Firma transazione -> Invio via TransactionSender -> Attesa on-chain -> Mostra ConfettiView.

Verifica Codice: Analizzare CreatePiggyBankViewModel. La chiamata TransactionSigner deve essere protetta dal Secure Enclave, seguita dal broadcasting.

Test 12: Creazione Target-Lock (Validation)

Azione: Inserimento Target "0" o importo negativo.

Desired Outcome: Il bottone "Create" è grigio/disabilitato. ToastView di avviso se forzato.

Verifica Codice: Verificare le computazioni derivate in SwiftUI (es. isFormValid).

Test 13: Creazione Fallita (Revert on-chain)

Azione: Transazione fallita (es. Out of Gas o RPC error).

Desired Outcome: BlockchainErrorView mostrata. La UI non aggiunge finti PiggyBank alla cache.

Verifica Codice: Il blocco do/catch in TransactionSender deve lanciare un enum di errori gestibile dalla UI. Nessun inserimento ottimistico incontrollato nel DB locale.

Test 14: Selezione Multi-Asset

Azione: L'utente cambia l'asset del salvadanaio da USDC a PAXG.

Desired Outcome: Il design della card in anteprima (PiggyCard) cambia colore dinamicamente (Giallo PAXG, Blu USDC).

Verifica Codice: Controllare l'infrastruttura di Theme.swift e come gli enum di Asset.swift sono mappati ai colori.

Test 15: Chiusura Sheet Involontaria

Azione: Swipe down sullo sheet di creazione mentre la transazione è "Pending".

Desired Outcome: Il gesto di dismissione deve essere bloccato (interactiveDismissDisabled(true)) finché pending.

Verifica Codice: Verifica la presenza del modificatore .interactiveDismissDisabled(isDeploying) in CreatePiggyBankView.

🟣 MODULO 4: Interazione Salvadanai (Flussi 16-20)

Test 16: Deposito in un PiggyBank

Azione: Tap su "Versa" e conferma importo.

Desired Outcome: Trasferisce fondi dal balance libero del Safe al modulo on-chain. Aggiorna la ProgressRing.

Verifica Codice: Controllare la chiamata ad ABIEncoder per la funzione deposit() e la successiva query di update.

Test 17: Sblocco Prematuro (Time-Lock Blocked)

Azione: Tentativo di prelievo (Unlock) prima della data di maturità.

Desired Outcome: Bottone grigio. Se bypassato (es. API injection), UI mostra alert "Locked by Smart Contract" leggendo la revert reason.

Verifica Codice: La logica di controllo del tempo deve essere sia client-side (UI) sia protetta dal catch in caso di esecuzione on-chain errata in PiggyBankDetailView.

Test 18: Sblocco a Maturità (Success)

Azione: Tap su Unlock a data raggiunta.

Desired Outcome: Auth Biometrica -> Transazione on-chain -> Svuota i fondi nel balance "libero" -> Salvadanaio "Completato".

Verifica Codice: Controllo integrazione FaceID prima della firma di svuotamento.

Test 19: Off-Ramp / Prelievo Esterno

Azione: Utente preme "Ritira su Conto Bancario".

Desired Outcome: Apre SellFlowSheet o WebView Mt Pelerin pre-compilata con l'address del Safe dell'utente.

Verifica Codice: Verificare i parametri passati alla WebView in MtPelerinService.swift.

Test 20: Ricezione Fondi (On-Ramp)

Azione: Tap su "Ricevi".

Desired Outcome: QRCodeGenerator crea QR. Copia in clipboard genera un Toast verde "Copiato".

Verifica Codice: Assicurarsi che UIPasteboard venga usato correttamente senza memory leak delle immagini QR.

🔴 MODULO 5: Gestione Sessione, Logout e Re-Login (Flussi 21-30)

Test 21: Cross-Login Stessa Email

Azione: Utente usa Apple Sign-In. Fa logout. Rientra con Google usando la STESSA email.

Desired Outcome: Genera la stessa PKP. L'app riconosce l'utente e ripristina i fondi.

Test 22: Rientro Offline

Azione: Logout. Aereo mode. Apre app.

Desired Outcome: Il login è inibito. Impossibile contattare Lit Protocol. Mostra errore "Rete necessaria per l'accesso".

Test 23: Cache Bleeding tra Account

Azione: Utente A (10k USDC) fa logout. Utente B (nuovo) entra.

Desired Outcome: La dashboard di B mostra 0. Nessun flash temporaneo dei dati di A.

Test 24: Logout durante Tx Pending

Azione: Tap "Deposita" -> Invia transazione -> Corre subito nei Settings e fa Sign Out.

Desired Outcome: La transazione on-chain prosegue (non può essere fermata), ma l'app locale si resetta pulita senza crashare per i callback persi in background.

Test 25: Token OIDC Expiry in sessione

Azione: Il JWT di Google/Apple scade (dopo X ore) mentre l'app è aperta.

Desired Outcome: LitProtocolService lo rileva e rigenera silente il token o chiede re-auth senza far crashare i successivi calcoli MPC.
(Test 26-30 includono test di stress sui bottoni social, validazione JWT locale, pulizia dei Cookie della WebView, e revoca manuale dal pannello Apple ID).

Verifica Codice: Ispezionare WalletCacheService per garantire il teardown atomico alla disconnessione. Analizzare i wrapper Task per evitare conflitti asincroni.

🟡 MODULO 6: Advanced Re-Login & Session Edge Cases (Flussi 31-40)

Test 31: App Kill durante MPC Handshake

Azione: Durante la rotella di calcolo Lit Protocol, kill manuale dell'app.

Desired Outcome: Al riavvio, non ci sono stati corrotti. Torna alla Auth.

Test 32: FaceID Negato dall'Utente al Login

Azione: L'utente preme "Continua" e poi annulla il prompt di FaceID.

Desired Outcome: L'app sblocca il bottone e non rimane in freeze.

Test 33: Debouncing Login Buttons

Azione: Tap furioso 10 volte su "Continua con Apple".

Desired Outcome: Solo una richiesta viene inviata, le altre ignorate.

Test 34: Ricostruzione On-Chain Totale

Azione: Utente elimina i dati di cache, entra.

Desired Outcome: BlockchainService scansiona i log storici di Base e ricostruisce tutti i PiggyBank passati in modo trasparente.
(Test 35-40 includono: Auth in background, Switch lingua OS durante login causante refresh views, permessi negati, ripristino da backup criptato).

Verifica Codice: @AppStorage vs KeychainService. Assicurarsi che BiometricService gestisca l'errore LAError.userCancel chiudendo i task in corso in AuthViewModel.

🟠 MODULO 7: Extreme Edge Cases & System Stress (Flussi 41-50)

Test 41: Rate Limiting 429 da Base RPC

Azione: L'app spamma chiamate eth_call. Il nodo risponde 429 Too Many Requests.

Desired Outcome: Il service attua una logica di Exponential Backoff e non bombarda l'utente di Toast di errore.

Test 42: Data/Ora Alterata (Time-Travel)

Azione: Utente sposta avanti la data dell'iPhone per sbloccare il Time-Lock.

Desired Outcome: Il backend dello Smart Contract rifiuta la tx. La UI gestisce l'errore senza aggiornare fraudolentemente lo stato locale.

Test 43: Disco Pieno al Logout

Azione: Memoria iPhone 100% piena. App tenta di svuotare o scrivere la Cache.

Desired Outcome: Evita fatalError() in caso di IOError di SQLite/CoreData/UserDefaults.
(Test 44-50 includono: Ghost UI in NavigationStack, schema migration di DB vecchi, ricezione JSON corrotto dal block explorer, Drop Socket wss://).

Verifica Codice: Analizzare BaseNetwork.swift per la gestione HTTP Status Codes (429, 503) e le policy di retry in BlockchainService.

🟤 MODULO 8: Migrazione Dispositivo & Installazione Pulita (Flussi 51-60)

Test 51: Zero Cache Hydration (Device Nuovo)

Azione: Installazione da TestFlight su telefono nuovo. Accesso con identità vecchia.

Desired Outcome: Recupero perfetto degli Smart Contract dal grafico EVM senza alcun input manuale dell'utente.

Test 52: iCloud Keychain Disattivato

Azione: Utente non usa iCloud. Login genera chiave Secure Enclave locale.

Desired Outcome: App funziona. Se utente cambia telefono, l'app avvia la procedura di ricalcolo del PKP via Auth Social.

Test 53: Sensore Biometrico Alterato

Azione: Utente aggiunge una nuova faccia al FaceID di iOS.

Desired Outcome: Il token nel Keychain viene invalidato dall'OS (.biometryCurrentSet). L'app forza un sign-out di sicurezza o richiede ri-associazione.
(Test 54-60 includono: Dual-device run contemporaneo, restore da backup MAC offline, bypass di app clonate).

Verifica Codice: Analizzare i flag di SecAccessControlCreateWithFlags in SecureEnclaveService.swift.

🟣 MODULO 9: Edge Cases Complessi di Identità e Conflitti (Flussi 61-70)

(Test esplicitamente richiesti)

Test 61: Errore Critico Scrittura Keychain Post-Logout (Keychain Locked)

Azione: Sign Out. Device viene bloccato con power button istantaneamente. Accesso scrittura negato dall'OS. Riapertura.

Desired Outcome: Rileva corruzione. Nessun force-unwrap (!). Pialla la entry corrotta, richiede ciclo completo Auth.

Verifica Codice: KeychainService.swift -> Gestione di errSecInteractionNotAllowed e nil coalescing.

Test 62: Accesso con Account Vergine Immediatamente Post-Logout

Azione: L'utente A esce. L'utente B (mai visto prima) accede subito dopo.

Desired Outcome: Generazione nuovo PKP -> Ricerca Safe fallisce -> Deploy silente Safe -> Saldi a Zero. Zero bleeding.

Verifica Codice: SafeService.swift e AppState.swift per isolamento namespace e reset dei @Published properties.

Test 63: Disinstallazione Brutale senza Sign Out (Orphaned Session)

Azione: Elimina App dalla Home iOS -> Reinstalla.

Desired Outcome: Chiave Enclave persa. JWT Lit forse attivo ma inutilizzabile. Presenta AuthView e impone nuovo Apple/Google Sign In nativo.

Verifica Codice: Controllare il fallback nel check iniziale in PiggyVaultApp.swift.

Test 64: Timeout Esatto sulla Generazione PKP

Azione: Rete muore esattamente durante MPC calcolo (Lit). Supera 30s.

Desired Outcome: Task cancellato. Timeout gestito. Toast: "Rete lenta. Riprova". No Infinite Loader.

Verifica Codice: Implementazione di withThrowingTaskGroup o Task.sleep per timeout racing in LitProtocolService.swift.

Test 65: Disallineamento "Hide My Email" di Apple

Azione: Utente cambia telefono, fa login Apple e toglie la spunta da "Nascondi Email" precedentemente usata.

Desired Outcome: App carica portafoglio VUOTO (PKP diversa). Banner UI mostra suggerimento: "Non trovi i fondi? Assicurati di non aver modificato 'Nascondi Email'".

Verifica Codice: Logica di onboarding in DashboardViewModel per gli account vergini.

Test 66: Re-Login post Ricarica Esterna Offline (External Funding)

Azione: Utente fa Sign Out. Riceve bonifico Mt Pelerin di 1000 USDC offline. Fa Sign In.

Desired Outcome: Hydration cache rileva i fondi prima del render. Auto-Gas swap per ETH scatta in background. Salvadanaio pienamente operativo.

Verifica Codice: Ordine di esecuzione fetchBalances() e checkGas() post login.

Test 67: Sospensione iOS durante il Prompt FaceID di Login

Azione: Appare FaceID -> Background app per 10 minuti -> Riapre app.

Desired Outcome: AuthViewModel resetta lo stato di caricamento. Bottone "Continua" premibile di nuovo.

Verifica Codice: Gestione lifecycle (scenePhase) in RootView.

Test 68: Conflitto Nonce su Transazioni Multi-Dispositivo

Azione: Utente preme "Deposita" simultaneamente da due iPhone con lo stesso account.

Desired Outcome: Cattura RPC Error (nonce too low). Rigenera nonce e ritenta, o mostra errore di conflitto chiaro e amichevole.

Verifica Codice: Gestione del retry pattern in TransactionSender.swift.

Test 69: Spamming Orizzontale del Tasto Sign Out ("Rage Quit")

Azione: Tap furioso 15 volte su "Sign Out" rosso in Settings.

Desired Outcome: Disabilitazione bottone al primo tap. Prevenzione crash da alert multipli.

Verifica Codice: Presenza di flag @State isLoggingOut in SettingsView.

Test 70: Re-Login in Low Data Mode (Risparmio Dati iOS)

Azione: "Consumo Dati Ridotto" attivo da Settings OS. Accesso App.

Desired Outcome: Rilevamento path .isConstrained. Incremento automatico Timeout API Auth (es. 45s invece di 15s).

Verifica Codice: Lettura di NWPathMonitor in NetworkMonitor.swift associata alla config di URLSession.

🔐 MODULO 10: Sicurezza Hardware & Edge Cases Architetturali (Flussi 71-80)

Test 71: Revoca Remota Google Token

Azione: L'utente revoca i permessi dell'app dalla dashboard account Google via PC, con app in uso.

Desired Outcome: Al successivo check OIDC, il nodo Lit rifiuta la firma. App esegue fallback gracefully e richiede il ri-login.

Test 72: Lockout Biometrico (FaceID bloccato)

Azione: L'utente tenta con occhiali/mascherina per 5 volte. FaceID richiede PIN sistema.

Desired Outcome: L'app delega correttamente il fallback al passcode di sistema iOS se configurato per le operazioni base, ma NON per la generazione chiavi critiche.
(Test 73-80: VPN Drop pre-firma, Jailbreak detection hook, ptrace attach da debugger, kill-switch certificati APNs).

Verifica Codice: Analisi BiometricService.swift (LAPolicy.deviceOwnerAuthenticationWithBiometrics vs generico).

🏗️ MODULO 11: Ciclo di Vita Avanzato dei Salvadanai (Flussi 81-90)

Test 81: Prevenzione Doppio Deploy (Spam Button)

Azione: Su rete lenta, l'utente preme "Deploy" su un PiggyBank tre volte di fila.

Desired Outcome: Solo uno Smart Contract clonato, button freezato istantaneamente.

Test 82: Boundary Test Target-Lock

Azione: Target = 100 USDC. Saldo = 99.9999 USDC. Tap su Sblocca.

Desired Outcome: Smart Contract esegue REVERT. La UI sa prevenire questo errore e disabilita il bottone indicando che manca una frazione minima.

Test 83: Distruzione / Autoclear di Contratti Vuoti

Azione: Il PiggyBank viene svuotato a maturità.

Desired Outcome: La UI lo sposta nei "Completati". Il bilancio del modulo on-chain resta 0.
(Test 84-90: Crollo di Gas Fee a metà strada, Unpredictable Gas Limit, Esecuzione fallita del fallback function).

Verifica Codice: Calcoli decimali BigInt in CurrencyFormatter e ABIEncoder per evitare l'underflow.

🔄 MODULO 12: Cross-Device e Retrieval senza Database (Flussi 91-100)

Test 91: Archeologia Metadati via Base Logs

Azione: Refresh forzato della Dashboard su device nuovo.

Desired Outcome: BlockchainService invia payload eth_getLogs filtrato sui topic della PiggyModuleFactory. Costruisce la UI da zero interpretando i byte.

Test 92: Fallback Explorer API (RPC Ostruito)

Azione: Nodo RPC Base non risponde alla query di log (troppo pesante).

Desired Outcome: L'app esegue switch automatico a BaseScan REST API per scaricare gli eventi di creazione dei PiggyBank.
(Test 93-100: Decode JSON errati dai log, UI State synchronization delay, Pagination dei log su oltre 10.000 blocchi).

Verifica Codice: Analizzare le fallback API struct in BaseNetwork e l'architettura dei decoder RLP.

🌐 MODULO 13: Resilienza di Rete e Blockchain (Flussi 101-110)

Test 101: Mempool Eviction (Transazione Droppata)

Azione: Transazione di deposito inviata con Gas troppo basso a causa di spike improvvisi della rete Base.

Desired Outcome: La transazione scompare dalla mempool dopo N minuti. L'app rileva lo stallo, annulla l'UI pending e avvisa l'utente di riprovare.

Test 102: Retry Underpriced Fee ("Speed Up")

Azione: Come sopra, ma l'app rileva la fee underpriced proattivamente e (se programmato) propone un bump automatico della fee ricalcolando la firma (nonce uguale).

Test 103: Smart Contract Inviolabilità (Time-Lock bypass)

Azione: Simulata transazione di withdraw via script esterno prima del tempo.

Desired Outcome: Transazione on-chain fallisce (Revert).

Test 104: Connessione droppata tra firma e broadcast

Azione: FaceID ok -> transazione firmata -> Wi-Fi salta.

Desired Outcome: L'app rileva l'errore fetch prima che il transaction hash venga generato. Nessun blocco UI, errore pulito.
(Test 105-110: Race condition nello sblocco simultaneo, Test dei limiti di Max Integer per scadenze nel 2099, Block Header validation mismatch).

Verifica Codice: Gestione dei Transaction Hash (txHash) pending, poll interval dei Receipt, validazione stato "Mined" in TransactionSender.


🛡️ MODULO 14: Sicurezza Attiva & Anti-Tampering (Flussi 111-140)

(30 Test approfonditi sull'autodifesa del client iOS contro vettori di attacco)

Test 111: Rilevamento Jailbreak Esteso (Kill-Switch)

Azione: Avvio app su iPhone con file Cydia/Sileo o symlink sospetti in /private/.

Desired Outcome: L'app crasha intenzionalmente o mostra un blocco totale "Dispositivo non sicuro". Disattiva chiavi.

Test 112: Prevenzione Screen Recording & Screenshot

Azione: L'utente apre la Dashboard e avvia "Registrazione Schermo".

Desired Outcome: L'app offusca immediatamente i saldi (∗∗∗∗) o mostra una view nera protettiva.

Test 113: Clipboard Poisoning Check (Incolla Indirizzo)

Azione: Incolla di un indirizzo alterato in memoria da un malware.

Desired Outcome: Il campo valida EIP-55. Se fallisce il checksum o la regex EVM, rifiuta l'input con un Toast.

Test 114: Background Snapshot Obfuscation

Azione: Swipe in alto per entrare nel Multitasking (App Switcher) lasciando l'app visibile.

Desired Outcome: sceneWillResignActive applica un Blur/Logo sopra l'app per nascondere i fondi a chi guarda lo schermo.

Test 115: Auto-Lock per Inattività (Session Timeout)

Azione: L'app rimane aperta senza tap per 3 minuti.

Desired Outcome: Appare BiometricLockView sovrapposta. Richiede FaceID per tornare a vedere o usare l'app.

Test 116: Tastiere di Terze Parti (Anti-Keylogging)

Azione: Inserimento cifre con tastiera SwiftKey "Full Access" abilitato.

Desired Outcome: Il sistema forza .keyboardType(.decimalPad) nativa di iOS inibendo le estensioni custom.

Test 117: Manipolazione Data/Ora Locale (Anti-Replay)

Azione: Cambio orologio iOS in un anno futuro per aggirare il Time-Lock.

Desired Outcome: La UI può sbloccarsi visivamente, ma il transactionSender fallirà in base al timestamp on-chain reale.

Test 118: Deep Link Spoofing

Azione: Tap su piggyvault://withdraw?to=hacker.eth.

Desired Outcome: Apperta, mostra un Alert critico "Richiesta esterna non verificata" chiedendo Auth forte prima di popolare la UI.

Test 119: Protezione contro Debugging Attivo

Azione: Compilazione con LLDB attaccato a runtime.

Desired Outcome: Se fattibile in Swift, uso di ptrace(PT_DENY_ATTACH) per chiudere l'app ed evitare letture RAM.

Test 120: Cancellazione Rapida Cache su Background Kill

Azione: Kill brutale dell'app (swipe up).

Desired Outcome: sceneDidDisconnect assicura che nessuna PKP rimanga in chiaro nei file di swap di memoria.

Test 121: Proxy MITM (Man In The Middle) Detection

Azione: Utente connesso a Wi-Fi pubblico con certificato proxy SSL custom installato.

Desired Outcome: L'app esegue SSL Pinning sulle API RPC e Lit. La connessione viene rifiutata prevenendo furto di token.

Test 122: Overlay Attack (Tapjacking)

Azione: Un'app malevola iOS (raro ma possibile tramite accessibility) disegna un layer invisibile sopra il bottone "Invia".

Desired Outcome: Il SecureEnclave di FaceID spezza il tapjacking richiedendo l'autenticazione hardware esplicita per l'invio.

Test 123: Reverse Engineering Plist (App Tampering)

Azione: Bundle ID o entitlements alterati tramite re-signing dell'IPA.

Desired Outcome: Il servizio Apple Sign-In e Lit Protocol falliscono la validazione del dominio/bundle invalidando l'app.

Test 124: Spoofing Dati Biometrici (3D Mask)

Azione: Tentativo di ingannare il FaceID.

Desired Outcome: iOS gestisce il blocco dopo X tentativi. PiggyVault scala automaticamente a richiedere il PIN alfanumerico (Fallback).

Test 125: Corruzione SQLi/XSS su Cache Locale

Azione: Modifica del file UserDefaults tramite iMazing inserendo payload XSS nei nomi dei PiggyBank.

Desired Outcome: SwiftUI sfugge nativamente l'HTML. La decodifica JSON strict previene SQL injection locali.

Test 126: Estrazione Keychain iCloud (Physical Access)

Azione: Telefono rubato ma sbloccato. Hacker prova a esportare le chiavi.

Desired Outcome: KeychainService deve usare l'attributo kSecAttrAccessibleWhenUnlockedThisDeviceOnly per impedire l'export della passkey.

Test 127: Dati Modificati in Transito (Tampered RPC)

Azione: Nodo RPC compromesso restituisce un ABI falsato durante la lettura dei PiggyBank.

Desired Outcome: ABIEncoder fallisce il decoding stretto dei tipi Solidity e droppa i dati invece di mostrare dati corrotti.

Test 128: Prevenzione Replay Attack (Nonce Management)

Azione: Hacker intercetta la firma offline e prova a ritrasmetterla su Base.

Desired Outcome: Lo Smart Contract Safe e la logica Nonce rigettano la transazione vecchia (standard EVM).

Test 129: Fake App Update (Sideloading)

Azione: Installazione di PiggyVault alterato tramite AltStore sopra la versione originale.

Desired Outcome: Il Keychain previene la lettura delle chiavi da parte di un binario con certificato dev differente.

Test 130: Offline Brute-Force Locale

Azione: Dump del telefono offline e tentativo di decriptare WalletCacheService.

Desired Outcome: Poiché la cache è salata con l'ID utente/PKP derivato da Lit, è illeggibile senza l'autorizzazione OAuth di rete.

Test 131: Manipolazione GPS (Geo-Spoofing per OFAC)

Azione: Utente sanzionato usa un Fake GPS per bypassare i blocchi regionali di Mt Pelerin.

Desired Outcome: I controlli IP-based lato server (Cloudflare/Mt Pelerin) superano l'inganno GPS bloccando la transazione.

Test 132: Iniezione Processi in Background

Azione: Dispositivo compromesso tenta di leggere la RAM di PiggyVault in background.

Desired Outcome: L'app azzera le variabili sensibili @State crittografiche quando entra nello stato background.

Test 133: Validazione Indirizzo Destinazione (Zero-Width Chars)

Azione: Indirizzo incollato contiene caratteri invisibili (Unicode zero-width) usati per phishing.

Desired Outcome: La funzione di pulizia indirizzi fa lo strip totale dei caratteri non esadecimali prima della validazione.

Test 134: Compromissione Dipendenze SPM

Azione: Un pacchetto Swift di terze parti viene aggiornato maliziosamente per rubare dati.

Desired Outcome: Minimizzazione assoluta dei pacchetti esterni. Network chiamate ristrette tramite App Transport Security (ATS).

Test 135: Modifica Biometria Mid-Session

Azione: L'utente aggiunge un'impronta o una faccia nuova nelle impostazioni iOS.

Desired Outcome: Il Keychain invalida la passkey. PiggyVault rileva il cambio e forza un Re-Login Lit Protocol di sicurezza.

Test 136: Intercettazione Push Notification

Azione: Un'app terza spia le notifiche in arrivo.

Desired Outcome: Le push di PiggyVault (es. "Fondi ricevuti") non conterranno MAI indirizzi completi o seed in chiaro.

Test 137: Alterazione UI tramite Accessibilità

Azione: Sfruttamento di tool di accessibilità per cliccare bottoni nascosti.

Desired Outcome: I bottoni inattivi (disabled(true)) non devono poter innescare l'action nemmeno se forzati via script.

Test 138: Fuzzing Input Test

Azione: Inserimento di 10.000 caratteri casuali nel campo "Nome Salvadanaio".

Desired Outcome: Limite caratteri stretto sulla Textfield (es. 20 char) per evitare buffer overflow in memoria o gas infinito.

Test 139: Rifiuto Certificati Revocati (CRL)

Azione: I nodi Lit Protocol subiscono un breach di sicurezza sui certificati HTTPS.

Desired Outcome: iOS rifiuta nativamente la connessione grazie alla revoca del certificato, proteggendo la PKP.

Test 140: Isolamento WebView

Azione: La WebView di Mt Pelerin tenta di eseguire JS malevolo per accedere al localStorage di PiggyVault.

Desired Outcome: La WKWebView gira in una sandbox separata. Nessun accesso ai cookie nativi o al UserDefaults dell'app madre.

💶 MODULO 15: Integrazione Fiat/Crypto & On-Ramp (Flussi 141-170)

(30 Test sul Bridge API Mt Pelerin, KYC, Limiti e Comportamenti Finanziari Fiat)

Test 141: Generazione IBAN Dedicato Fallita (Mt Pelerin Down)

Azione: Chiamata API per creare l'IBAN Safe dell'utente restituisce 500.

Desired Outcome: Mostra Skeleton loader -> Timeout -> Messaggio: "Servizi bancari temporaneamente non disponibili".

Test 142: Violazione Limite KYC Giornaliero (No-KYC Limit)

Azione: L'utente senza documenti cerca di comprare >1000 CHF/giorno.

Desired Outcome: Il widget Web intercetta il limite e la WebView mostra il funnel di caricamento documenti di Mt Pelerin.

Test 143: Timeout del Widget di Acquisto (Slippage Expired)

Azione: Widget aperto, utente aspetta 20 minuti prima di pagare.

Desired Outcome: Preventivo scade. PiggyVault cattura l'evento di reload e aggiorna i parametri senza mostrare pagine bianche.

Test 144: Bonifico SEPA Arrivato in Background (Silent Sync)

Azione: Bonifico Fiat processato mentre l'app è chiusa.

Desired Outcome: Background Task rileva l'aumento su Base. Emette Push Locale: "I tuoi fondi sono arrivati! +500 USDC".

Test 145: Chiusura Anticipata (Rage Quit) del Modale Off-Ramp

Azione: Swipe down sul widget mentre si sta ritirando verso banca.

Desired Outcome: Action Sheet protettivo: "Stai chiudendo la finestra. Se non hai autorizzato, l'operazione sarà annullata."

Test 146: Adeguamento Valuta UI vs Valuta On-Ramp

Azione: Utente compra in EUR, ma ha PiggyVault impostato su CHF.

Desired Outcome: CurrencyFormatter converte solo visivamente (Display) usando Oracolo prezzi. Nessuna perdita reale percepita.

Test 147: Transazione Off-Ramp Bloccata (AML Check)

Azione: Mt Pelerin mette in pausa il bonifico per controlli Antiriciclaggio.

Desired Outcome: TransactionHistoryView decodifica lo stato "Compliance Check" mostrando un pallino arancione "Verifica in corso".

Test 148: Intercettazione Errore Network nel Widget Web

Azione: Cade il 4G dentro la WebView.

Desired Outcome: Sovrappone BlockchainErrorView mascherando l'errore nativo in inglese di iOS.

Test 149: Contratto ERC20 Approve Fallito (Spender non approvato)

Azione: Utente prova a prelevare USDC verso Mt Pelerin ma annulla la firma biometrica di Approvazione.

Desired Outcome: Flow bloccato a monte. Toast: "Devi approvare il provider per completare il prelievo."

Test 150: Spoofing Prevention in WebView (Wallet Change Attack)

Azione: URL iniezione cerca di cambiare il parametro dest={Hacker_Address} nel link Mt Pelerin.

Desired Outcome: MtPelerinService verifica in rigidamente che dest corrisponda sempre a AppState.safeAddress prima di caricare la View.

Test 151: Name Mismatch (Nome Banca vs Nome KYC)

Azione: Utente fa bonifico da un conto a nome "Mario Rossi" verso l'IBAN Mt Pelerin intestato ad "André".

Desired Outcome: Il bonifico viene rigettato da Mt Pelerin. L'app PiggyVault, via Webhook o polling API, notifica: "Bonifico rifiutato per incongruenza intestatario."

Test 152: Attempt On-Ramp da Nazione Non Supportata (Es. USA)

Azione: Utente cerca di comprare crypto con carta emessa in USA (spesso bloccata per policy Mt Pelerin).

Desired Outcome: Il widget rileva il BIN della carta, blocca l'acquisto. PiggyVault mantiene la UI stabile e chiudibile.

Test 153: Rifiuto Acquisto Minor Età

Azione: Durante il KYC nel widget, l'utente inserisce una data di nascita < 18 anni.

Desired Outcome: Sospensione account Mt Pelerin. Il Widget mostra divieto. L'app non crasha e permette di tornare alla Dashboard.

Test 154: Verifica Limite Volume Annuale (100.000 CHF)

Azione: L'utente ha speso 99.000 CHF. Cerca di fare On-Ramp di 2.000 CHF.

Desired Outcome: Il widget forza il passaggio al Tier 2 (Video identificazione o source of funds) prima di processare l'extra importo.

Test 155: Ritorno Fiat (Bounced SEPA)

Azione: IBAN di destinazione chiuso. Il prelievo (Off-Ramp) fallisce e Mt Pelerin rimanda indietro le crypto.

Desired Outcome: Il saldo del Safe aumenta improvvisamente. L'app mappa la transazione inbound come "Storno Prelievo" nella cronologia.

Test 156: Alta Tolleranza Slippage su Transazioni Fiat->Crypto

Azione: Il mercato è iper-volatile. 100 EUR comprano 90 USDC invece dei 98 stimati.

Desired Outcome: Se il widget completa l'operazione, la Dashboard aggiorna il saldo a +90. Nessun disallineamento matematico locale.

Test 157: Delisting Token durante Off-Ramp

Azione: L'utente prova a prelevare PAXG, ma Mt Pelerin ha appena disabilitato il supporto a PAXG su rete Base.

Desired Outcome: Il menu a tendina o la WebView genera un errore di asset non supportato. PiggyVault consiglia di "Scambiare in USDC prima di prelevare".

Test 158: Bonifico Multiplo Stesso Importo (Duplicate Tx)

Azione: L'utente invia due bonifici identici di 100 EUR a distanza di 1 minuto all'IBAN.

Desired Outcome: Entrambi generano Transfer on-chain. La History UI li mostra come due righe distinte con hash di transazione differenti.

Test 159: Apple Pay Limit / 3D Secure Fallito

Azione: L'utente usa Apple Pay nel widget, ma la banca rifiuta per mancanza di 3D Secure.

Desired Outcome: Il modale Apple Pay scompare. Il widget mostra errore. L'utente resta dentro PiggyVault per riprovare con altra carta.

Test 160: Extrema Frazione Decimale Fiat (Micro centesimi)

Azione: Bonifico in entrata di 0.01 EUR.

Desired Outcome: Convertito in ~0.01 USDC. L'UI di PiggyVault gestisce i decimali formattandoli correttamente ("$0.01") senza arrotondare a zero.

Test 161: Spike Improvviso Fee Base Network durante On-Ramp

Azione: Mt Pelerin deve inviare USDC al Safe, ma la rete Base va in congestione e le fee salgono a 5$.

Desired Outcome: Mt Pelerin potrebbe posticipare l'invio. PiggyVault attende passivamente gli eventi blockchain, senza mostrare finti stati "Pending" se l'API non ha ancora trasmesso.

Test 162: Disconnessione Rete durante Cambio Vista Mt Pelerin

Azione: Utente clicca "Continua" nel widget, il widget fa un redirect interno, la rete cade.

Desired Outcome: WebView cattura errore. Bottone di ricarica pagina inietta nuovamente i parametri originali.

Test 163: Sessione Multipla On-Ramp

Azione: L'utente apre il foglio di deposito, lo abbassa (senza chiudere), ne apre un altro.

Desired Outcome: SwiftUI non impila modali multipli (sheet). Permette una sola istanza attiva del widget di acquisto.

Test 164: Revoca Chiavi API Mt Pelerin (Sicurezza B2B)

Azione: Le API Key aziendali di PiggyVault vengono ruotate o revocate per sicurezza.

Desired Outcome: Alla richiesta dell'IBAN, l'app riceve 401 Unauthorized. Mostra "Servizio in manutenzione" anziché esporre l'errore server all'utente.

Test 165: Elaborazione Rimborso On-Chain (Refund)

Azione: Utente compra tramite carta rubata, Mt Pelerin fa chargeback e revoca gli USDC dal Safe (se possiedono admin rights, sebbene improbabile nel non-custodial, test concettuale).

Desired Outcome: L'app traccia il trasferimento in uscita Transfer(Safe, Out) e lo mostra chiaramente come "Prelievo Forzato/Rimborso".

Test 166: Cambio Valuta Base in App (Multi-Currency Support)

Azione: Utente residente in UK cambia l'app in sterline (GBP) e apre il widget di deposito.

Desired Outcome: MtPelerinService passa dinamicamente sourceCurrency=GBP al widget per personalizzare l'on-ramp.

Test 167: Lettura Webhook Latenza Lunga

Azione: Mt Pelerin ci mette 4 ore a processare un SEPA.

Desired Outcome: Nessun caricamento infinito in app. Il deposito è considerato puramente asincrono.

Test 168: Widget Cache Bloat (Pulizia Memoria)

Azione: Utente apre e chiude il widget 50 volte.

Desired Outcome: Le istanze WKWebView vengono distrutte (de-init) per evitare memory warning dell'iPhone.

Test 169: Passaggio da Widget a Verifica Browser Esterno

Azione: La banca dell'utente impone l'apertura dell'app bancaria (es. Revolut) per autorizzare l'acquisto carta nel widget.

Desired Outcome: L'app gestisce il Deep Link in uscita verso Revolut e il ritorno fluido in PiggyVault per completare il flow.

Test 170: Ricezione Fiat Rifiutata per Indirizzo Smart Contract (Safe)

Azione: Alcuni exchange non inviano a Smart Contract (Safe).

Desired Outcome: Essendo Mt Pelerin specializzato in Bridge, questo non accade. Ma PiggyVault avvisa nel QR code: "Invia fondi solo tramite network Base. Questo è uno Smart Contract Wallet."

⛽ MODULO 16: Gas Abstraction Iniziale & Auto-Swap (Flussi 171-200)

(30 Test sulla logica: Cold Start 0 ETH = Manuale (Mt Pelerin), Manutenzione > 0 ETH = Auto-Swap invisibile)

Test 171: Cold Start Assoluto (0 ETH) - Blocco Azioni

Azione: Utente appena importato ha 10.000 USDC ma esattamente 0 ETH (0 Wei). Preme "Crea Salvadanaio".

Desired Outcome: GasManager rileva 0 ETH. La chiamata blockchain viene annullata. La UI fa scattare l'apertura del GasBuyETHSheet obbligatorio (Mt Pelerin) o mostra il QR code per deposito esterno, spiegando: "Serve gas iniziale per la tua prima operazione."

Test 172: Risoluzione Cold Start via Bonifico (External Receive)

Azione: Utente a 0 ETH invia manualmente 1$ in ETH da Coinbase al suo Safe.

Desired Outcome: BlockchainService rileva i fondi in entrata. GasManager passa allo stato .sufficient. Tutti i bottoni disabilitati dell'app (Deposita/Crea) diventano istantaneamente cliccabili. Il banner di richiesta gas scompare.

Test 173: Risoluzione Cold Start via Mt Pelerin

Azione: L'utente esegue l'acquisto minimo di ETH con carta nel widget aperto al Test 171.

Desired Outcome: Alla conferma dell'arrivo on-chain, il foglio si chiude automaticamente. L'utente è libero di operare.

Test 174: L'Auto-Swap Invisibile (Motore di Manutenzione)

Azione: L'utente ha 500 USDC e 0.40$ in ETH. La soglia Warning di GasManager è 0.50$.

Desired Outcome: Non appare NESSUN banner all'utente. In background, il servizio intercetta la soglia bassa, genera una transazione di swap su Uniswap V3 (USDC -> ETH) per il valore di 2$, la firma con la passkey silente e ricarica il gas. L'utente non si accorge di nulla, se non vedendo 498 USDC invece di 500. L'esperienza UX è salva.

Test 175: Fallimento Auto-Swap per Mancanza di Stablecoin

Azione: Il gas ETH scende a 0.40$. Il sistema tenta l'auto-swap, ma l'utente ha 0 USDC (tutto chiuso nei salvadanai).

Desired Outcome: L'auto-swap abortisce senza crash. Poiché non c'è modo di automantenersi, ORA GasManager espone il GasAlertBanner arancione: "Gas in esaurimento, ricarica manualmente o deposita USDC per le automazioni."

Test 176: Prevenzione Loop Infinito Auto-Swap (Rate Limiting)

Azione: L'auto-swap fallisce per rete intasata o slippage.

Desired Outcome: Il sistema NON ritenta in un loop forsennato bruciando batteria. Applica un "Exponential Backoff" (riprova dopo 1 min, 5 min, 30 min) o si mette in pausa per 12 ore.

Test 177: Slippage Superato durante Auto-Swap

Azione: Il router DEX invia la transazione in background (2 USDC -> ETH), ma nel blocco il prezzo di ETH crolla oltre la soglia slippage ammessa (es. 0.5%).

Desired Outcome: Transazione fallita on-chain. GasManager intercetta l'evento di revert, non scala gli USDC all'utente e ri-schedula il tentativo.

Test 178: Carenza Gas Pre-Sblocco (Ma con Auto-Swap Imminente)

Azione: ETH a 0.30$ (Critico). Utente tenta di fare "Unlock" di un salvadanaio da 1.000 USDC. L'unlock richiede 0.40$.

Desired Outcome: Il controllo preventivo blocca l'Unlock. Sapendo che l'auto-swap NON può avvenire perché non ci sono USDC liberi, richiede all'utente l'acquisto via Mt Pelerin.

Test 179: Ricarica Gas Ottimistica da Sblocco (Auto-Deduction)

Azione: Variante del 178: se si potesse detrarre la fee direttamente dallo sblocco.

Desired Outcome: Se lo smart contract lo permette, i fondi in uscita dal salvadanaio pagano la loro stessa fee al relayer (Gasless MetaTransaction). Altrimenti, prevale la logica manuale se a saldo 0 assoluto.

Test 180: Esecuzione Concorrente Auto-Swap e Transazione Utente

Azione: L'utente crea un PiggyBank proprio mentre il task in background sta swappando USDC per ETH (stesso nonce).

Desired Outcome: Gestione code transazioni. Una verrà rimpiazzata/fallirà. L'app rileverà l'errore di Nonce e rigenererà la firma della transazione dell'utente senza mostrare errori incomprensibili, dando priorità all'azione manuale.

Test 181: Aggiornamento Prezzo ETH/USDC via Oracolo Locale

Azione: Per decidere "quanti USDC vendere per ottenere 2$ in ETH", il sistema necessita del tasso di cambio.

Desired Outcome: L'app legge i prezzi da un oracolo (es. Chainlink su Base) o un'API off-chain veloce prima di formare la transazione di Auto-Swap.

Test 182: Saldo Dust Rimanente Post Swap (Centesimi Sporchi)

Azione: L'utente ha esattamente 2.01 USDC. L'Auto-Swap è settato a 2 USDC.

Desired Outcome: L'app lascia 0.01 USDC. Se il saldo rimanente è "polvere" (<0.05$), il modulo potrebbe essere programmato per scambiare tutto (MAX) per evitare micro-saldi fastidiosi in UI.

Test 183: Revoca Approvazione DEX (Router Approval)

Azione: L'utente usando un altro wallet revoca il permesso (Approve) allo smart contract di Uniswap di spendere i suoi USDC.

Desired Outcome: L'Auto-Swap fallisce localmente prima del broadcast (manca allowance). L'app mostra il banner: "Ri-autorizza il sistema automatico del gas per procedere."

Test 184: UI Invisibile per Task di Base (Silent Execution)

Azione: L'auto-swap parte mentre l'utente sta scrollando la lista dei salvadanai.

Desired Outcome: Nessun "Loading Spinner" centrale blocca l'utente. Forse solo un piccolissimo indicatore "Sincronizzazione Gas in background" nella status bar.

Test 185: Disconnessione Rete durante Task Gas

Azione: Il trigger scatta a 0.50$, l'app forma la transazione, ma il telefono va offline prima dell'invio.

Desired Outcome: Task sospeso. Non appena il telefono torna in 4G (grazie a NWPathMonitor), il task in volo viene ritrasmesso.

Test 186: Soglia Dinamica basata su L2 Base Congestion

Azione: Le fee su Base schizzano da 0.01$ a 1.00$ per tx.

Desired Outcome: GasManager ricalcola la soglia .warning. Se prima bastavano 0.50$ in cassa, con rete congestionata la soglia sale a 3.00$, triggerando l'Auto-Swap preventivamente.

Test 187: Gas Esaurito da Drenaggio Multiplo PiggyBanks

Azione: L'utente fa 5 depositi consecutivi super-rapidi verso 5 salvadanai. L'ETH crolla velocemente.

Desired Outcome: L'Auto-Swap non fa in tempo a ricaricare tra la prima e l'ultima. Il 5° deposito viene bloccato con "Gas insufficiente, ricarica in corso..." fino a che lo swap non viene minato.

Test 188: Auto-Swap con EURC invece di USDC

Azione: L'utente non ha USDC ma ha solo la stablecoin in Euro (EURC).

Desired Outcome: L'algoritmo di Auto-Swap è intelligente. Esamina la lista degli asset disponibili nel Safe e crea il routing corretto (EURC -> ETH) adattandosi ai fondi liberi.

Test 189: Mancanza Assoluta Liquidity Pool DEX (Estremo)

Azione: L'asset dell'utente (es. un token raro) non ha liquidità su Uniswap Base per scambiarlo in ETH.

Desired Outcome: Stima di swap fallisce per "No Liquidity". L'Auto-Swap abortisce in modo pulito e delega all'utente la responsabilità di ricaricare ETH manualmente tramite Mt Pelerin.

Test 190: Intercettazione Errore "Insufficient Funds for Gas" RPC

Azione: Per un bug, una transazione parte con 0 ETH reali. Il nodo blocca.

Desired Outcome: Invece di mostrare "RPC Error -32000", PiggyVault mappa il codice, lo formatta e apre istantaneamente il modale di salvataggio (Acquisto fiat).

Test 191: Disattivazione Volontaria Auto-Swap (Opt-Out)

Azione: L'utente (magari esperto) va in Impostazioni e disattiva il flag "Auto-Gestione Gas".

Desired Outcome: Il background task smette di monitorare la soglia e di vendere USDC. L'app scala al comportamento "Manuale": usa solo i Banner e i bottoni per avvisare di comprare gas quando finito.

Test 192: Task Auto-Swap Schedulato in Background iOS (Notte)

Azione: Il telefono è in ricarica alle 3 di notte.

Desired Outcome: Il BGAppRefreshTask di iOS controlla il gas. Se è sotto soglia, l'app usa le chiavi generate senza FaceID (se consentito dalle policy Keychain di background) o posticipa l'operazione al primo sblocco mattutino dell'utente.

Test 193: Aggiornamento Optimistico UI Post Swap

Azione: Swap inviato e confermato. L'oracolo ci mette 10 secondi ad aggiornare i prezzi Fiat.

Desired Outcome: L'app deduce temporaneamente 2$ in USDC dalla Dashboard in modo ottimistico prima ancora di leggere l'RPC, mantenendo l'esperienza immediata (zero sfarfallii del portafoglio).

Test 194: Ricalcolo Gas Limit per Contratti Complessi (PiggyFactory)

Azione: Creare un "Target-Lock" richiede il 30% di gas in più rispetto a un semplice invio ERC-20.

Desired Outcome: GasManager.estimateGasNeeded non usa un parametro fisso, ma chiama eth_estimateGas sul payload specifico del deploy. Se l'ETH in cassa non basta per QUELLA specifica operazione (ma basterebbe per un invio normale), triggera lo swap o l'avviso.

Test 195: Attacco Spam Drenaggio Gas (Prevenzione)

Azione: Un bug nell'interfaccia continua a chiamare firme fallite che bruciano frazioni di gas.

Desired Outcome: Il sistema blocca la successione di transazioni se individua troppi "Revert" consecutivi, bloccando l'Auto-Swap per proteggere gli USDC dell'utente da sprechi dovuti a loop.

Test 196: Cambio Rapido Asset Auto-Swap (Svendita)

Azione: L'app deve vendere per pagare gas. L'utente preme invio di TUTTI i suoi USDC verso un conto esterno.

Desired Outcome: L'app sa che servono fee in ETH. Deduce in tempo reale X USDC dal totale in uscita (MAX amount), li scambia in ETH (Auto-Swap batchato o preventivo) e invia il rimanente MAX - fee.

Test 197: Errore Node Base (Auto-Swap Timeout)

Azione: Swap inviato, ma Base L2 è bloccata.

Desired Outcome: L'operazione "Manutenzione" rimane pending e invisibile. Le operazioni utente che richiedono quell'ETH appena comprato dovranno attendere, mostrando "Preparazione portafoglio in corso...".

Test 198: Fallback Router DEX (Es. Aerodrome invece di Uniswap)

Azione: Uniswap V3 Base è in manutenzione o bloccato (molto raro).

Desired Outcome: Se l'auto-swap primario fallisce stima per contratto in pausa, prova un provider alternativo (es. Aerodrome/0x) mappato in app per la massima resilienza.

Test 199: Safe Module Abstraction per il Gas (Architettura Avanzata)

Azione: Il Safe Wallet è configurato con un FallbackHandler che permette il pagamento delle fee direttamente in ERC-20 tramite un bundler.

Desired Outcome: L'intero step di Auto-Swap potrebbe essere bypassato. Il Safe paga nativamente la fee in USDC decurtandola dal transato. L'app UX deve solo indicare "Fee pagata in USDC: 0.15$".

Test 200: Consistenza Saldo Totale (Net-Worth) Pre/Post Swap

Azione: Utente ha Patrimonio netto: 1000.00$. Avviene Auto-Swap (vende 2$ di USDC per 1.99$ di ETH).

Desired Outcome: Il Patrimonio netto scende a 999.99$ (a causa della micro-fee DEX e spread). L'app non registra un "crollo" e i grafici Dashboard rimangono fluidi senza candele anomale.

♿ MODULO 17: Accessibilità, UI Estrema e Conformità (Flussi 201-210)

(Test invariati per garantire accessibilità, voice over, traduzioni dinamiche, font test, e dark mode)

Test 201: Dynamic Type Max (Test Ipovisione)

Desired Outcome: Form testi lunghi scalabili con ScrollView. Nessun taglio anomalo su caratteri MAX.

Test 202: Compatibilità VoiceOver

Desired Outcome: Lettura intelligente delle "ProgressRing" ("Progresso 75%, 750 su 1000") invece di "Immagine".

Test 203: Fallback Localizzazione

Desired Outcome: Lingua Olandese -> Fallback morbido su Inglese (EN) in assenza di mappatura.

Test 204: Gestione Missing Translation Key

Desired Outcome: Chiave mancante tradotta automaticamente in alert generico anziché mostrare stringhe codice all'utente.

Test 205: Geo-Blocking OFAC

Desired Outcome: IP Sanzionato (es. Nord Corea) intercettato. Banner inamovibile di blocco servizi.

Test 206: Animazioni Reduce Motion

Desired Outcome: Confetti disabilitati. Animazioni di Spring diventano Fade se l'OS lo richiede.

Test 207: Hitbox Minime (Tremori)

Desired Outcome: Tap area minima 44x44 garantita su icone piccole tramite contentShape.

Test 208: Formattazione Valute Esotiche (INR/JPY)

Desired Outcome: Cifre lunghissime rimpicciolite dinamicamente senza andare a capo brutalmente.

Test 209: Switch Dark/Light Mode a Runtime

Desired Outcome: Colori palette aggiornati istantaneamente a tramonto senza riavvio.

Test 210: Blacklist USDC Circle (Congelamento)

Desired Outcome: Intercettazione errore "Blacklisted" on-chain. Avviso in italiano e non "Errore Rete".