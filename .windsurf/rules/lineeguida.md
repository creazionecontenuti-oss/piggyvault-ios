---
trigger: always_on
---

# Linee Guida PiggyVault
## Architettura Tecnica Finale

Questa è la struttura definita per André Wagner Vitiani. L'obiettivo è creare salvadanai digitali indistruttibili su smart contract con la massima accessibilità universale (iOS & Android) e sicurezza biometrica.

## Principi Fondamentali del Sistema

100% Non-Custodial: PiggyVault non è una banca e non detiene i fondi. L'utente ha il controllo esclusivo, matematico e crittografico dei propri risparmi. Nemmeno gli sviluppatori dell'app possono toccare i soldi.

Zero Database (Serverless Puro): L'architettura non prevede l'uso di alcun database centralizzato (nessun Supabase, Firebase, AWS RDS, SQL o NoSQL di alcun tipo). L'intero stato dell'applicazione, le regole e i saldi vivono esclusivamente sulla blockchain (rete Base) e sulla rete decentralizzata di Lit Protocol.

## La Cassaforte (SAFE) e i Moduli Salvadanaio

Ruolo: Gestione dei fondi e regole di sblocco.

Smart Account (Safe): Custodisce USDC, EURC e PAXG (Oro) su rete Base.

Moduli di Risparmio (Piggy Modules): Smart contract specializzati che impongono le regole di sblocco (Time-Lock o Target-Lock).

Immutabilità Totale: Una volta attivata una regola di blocco, il codice diventa definitivo. Nemmeno il detentore della chiave privata ha il potere di modificare o bypassare la regola. L'utente è protetto dalla propria impulsività.

## Il Fabbro delle Chiavi (LIT PROTOCOL) - Identità Universale

Ruolo: Garantire l'accesso cross-platform e il recupero dell'account indipendentemente dal dispositivo, senza database centrali.

Identità vs Firma: Lit Protocol gestisce l'Identità (chi è l'utente). Le Passkeys (FaceID/Android Biometrics) gestiscono la Firma (l'autorizzazione sulla singola transazione).

Metodi di Registrazione e Recupero (Fase Iniziale):

Apple ID: Standard nativo e iper-sicuro per utenti iOS.

Google Account: Obbligatorio/Standard per utenti Android (e cross-platform per chi ha entrambi).
(Per mantenere l'interfaccia pulita e la sicurezza ai massimi livelli garantiti dai giganti tech, per il momento si escludono metodi via email OTP o altri social).

Interoperabilità: Se André si registra su iPhone con Google, può accedere al suo salvadanaio su un tablet Android usando lo stesso account Google. La "chiave master" (PKP) viene ricomposta dai nodi Lit.

## Strategia di Sviluppo App

Ruolo: Fornire un'esperienza fluida e sicura su ogni ecosistema.

Fase 1: App Nativa iOS (Swift): Integrazione con Secure Enclave e FaceID per le firme quotidiane.

Fase 2: App Nativa Android (Kotlin): Utilizzo del Keystore di sistema e dei sensori biometrici Android.

Sincronizzazione Multi-Device: Grazie alla chiave gestita da Lit, l'utente può avere lo stesso account su più dispositivi contemporaneamente.

Fase 3: PWA su IPFS: Versione web decentralizzata per garantire l'accesso perpetuo anche se gli store ufficiali dovessero rimuovere l'app.

## On-Ramp e Gestione Identità (KYC Ottimizzato)

On-Ramp: Integrazione con Mt Pelerin Bridge API (On-ramp senza KYC fino a 1.000 CHF/giorno).

IBAN: Assegnazione di un IBAN personale che deposita i fondi direttamente nel Safe trasformandoli in stablecoin.

## Futuro: Carte di Pagamento (Gnosis Pay)

Carta Visa: Collegata ai fondi liberi (non vincolati) del Safe.

KYC Unico: Richiesto solo al momento dell'ordine della carta fisica.

## Autosufficienza Economica (Gas Management)

Sponsorizzazione: Il Relayer paga le prime operazioni (creazione account).

Auto-Gas: Dopo il primo deposito, l'app scambia automaticamente 2-5$ in ETH per rendere il salvadanaio autonomo.

## CONCLUSIONE

PiggyVault abbatte le barriere tra Apple e Android: i risparmi vivono sulla blockchain e l'accesso è legato all'identità digitale dell'utente (Google o Apple), non al singolo hardware. La disciplina di risparmio è garantita matematicamente dall'immutabilità degli smart contract, senza affidarsi a nessun database centrale hackerabile o censurabile.

## CONFIGURAZIONE AMBIENTE

Fare riferimento al file .env per le configurazioni necessarie. Guarda cosa c'è già configurato e cosa manca e semmai aggiungilo mano mano. Se hai bisogno di altre variabili, chiedilo pure.

## ISTRUZIONI OPERATIVE

Vai avanti a programmare e non fermarti mai. Se ti blocchi su qualcosa, cerca di risolvere il problema da solo e continua a programmare. Usa la scelta consigliata che non entra in conflitto con questa o altre regole.
Solo quando finisci l'app o veramente non puoi andare piu avanti senza di me allora fermati e chiedimi cosa fare. Se ti servo io ma ti viene in mente che puoi fare altro intanto prima di chiedermi qualcosa, fallo subito.

## FILE DI PROCRESSO

Mantieni un file di processo chiamato PROCESSO.md in cui annota cosa stai facendo, cosa hai fatto, cosa ti serve e quali decisioni hai preso. Questo ti aiuterà a mantenere la continuità e a ricordare le scelte architetturali. Usa dei timestamp per tenere traccia del tempo impiegato per ogni task. Aggiorna il file ad ogni sessione di lavoro e prima di chiudere la sessione di lavoro.

## Cose che puoi fare da solo anche quando credi di aver bisogno di me

Puoi andare sul web con playwright e fare gli account che ti servono. Troverai l account google gia loggato e potrai usare quello per fare i vari account che ti servono o per fare i login necessari per accedere ai vari servizi anche come google stesso o altro. Quindi se ti serve un account per un servizio, vai sul web con playwright e crea l'account. Se ti serve un login, vai sul web con playwright e fai il login.