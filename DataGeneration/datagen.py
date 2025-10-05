from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from typing import Any, cast
import random
import numpy as np
import pandas as pd
import re

# ===============================
# FASE 1: Imports y Atributos
# ===============================

@dataclass
class DataGenConfig:
    seed: int = 42
    start_date: datetime = datetime(2025, 1, 1)
    end_date: datetime   = datetime(2025, 10, 1)

    n_users: int = 200
    n_nfts: int = 600
    pct_nfts_in_auction: float = 0.60

    role_probs: Dict[str, float] = field(default_factory=lambda: {
        "ADMIN": 0.05, "ARTIST": 0.25, "CURATOR": 0.08, "BIDDER": 0.85
    })
    multi_role_prob: float = 0.35
    roles_per_user_range: Tuple[int, int] = (1, 3)

    emails_per_user_range: Tuple[int, int] = (1, 2)
    pct_primary_verified: float = 0.85
    email_domains: List[str] = field(default_factory=lambda: [
        "gmail.com", "outlook.com", "yahoo.com", "uni.edu.gt"
    ])

    balance_eth_range: Tuple[float, float] = (0.0, 20.0)
    reserved_eth_range: Tuple[float, float] = (0.0, 3.0)

    suggested_price_eth_range: Tuple[float, float] = (0.05, 5.0)
    content_types: List[str] = field(default_factory=lambda: [
        "image/png", "image/jpeg"
    ])

    default_auction_hours: int = 72
    min_bid_increment_pct: int = 5
    bids_per_auction_lambda: float = 6.0  # media Poisson

    status_catalog: Dict[str, List[str]] = field(default_factory=lambda: {
        "NFT": ["PENDING","APPROVED","REJECTED"],
        "AUCTION": ["ACTIVE","COMPLETED","CANCELLED"],
        "FUNDS_RESERVATION": ["ACTIVE","RELEASED","APPLIED"],
        "USER_EMAIL": ["ACTIVE","INACTIVE"],
        "EMAIL_OUTBOX": ["PENDING","SENT","FAILED"],
        "CURATION_DECISION": ["PENDING","APPROVED","REJECTED"]
    })

# ===============================
# Utilidades mínimas
# ===============================

def _rng(seed: int):
    random.seed(seed)
    np.random.seed(seed)

def _dt_between(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = random.randrange(int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)

_FIRST_NAMES = [
    # Nombres masculinos
    "Diego", "Juan", "Carlos", "Pedro", "Luis", "Marco", "José", "Jorge", "Andrés", "Hugo",
    "Miguel", "Rafael", "Fernando", "Ricardo", "Roberto", "Alejandro", "Francisco", "Javier",
    "Manuel", "Antonio", "Sergio", "Raúl", "Óscar", "Víctor", "Guillermo", "Rodrigo",
    "Ernesto", "Alberto", "Enrique", "Arturo", "Mauricio", "Gabriel", "Daniel", "Samuel",
    "Emilio", "Julio", "Ramón", "Tomás", "Ignacio", "Felipe",
    # Nombres femeninos
    "María", "Lucía", "Ana", "Sofía", "Elena", "Daniela", "Camila", "Valeria", "Paola",
    "Fernanda", "Andrea", "Carolina", "Gabriela", "Isabel", "Patricia", "Laura", "Claudia",
    "Mónica", "Silvia", "Rosa", "Carmen", "Teresa", "Beatriz", "Adriana", "Mariana",
    "Alejandra", "Natalia", "Verónica", "Cristina", "Diana", "Julia", "Lorena", "Cecilia",
    "Rocío", "Marta", "Sandra", "Gloria", "Raquel", "Susana", "Alicia"
]

_LAST_NAMES = [
    "Azurdia", "García", "Martínez", "López", "Hernández", "Gómez", "Pérez", "Ramírez",
    "Flores", "Torres", "Díaz", "Vásquez", "Castillo", "Ortiz", "Morales", "Reyes",
    "Cruz", "Mendoza", "Romero", "Silva", "González", "Rodríguez", "Sánchez", "Ruiz",
    "Jiménez", "Álvarez", "Vargas", "Guerrero", "Medina", "Rojas", "Contreras", "Guzmán",
    "Navarro", "Campos", "Aguilar", "Cabrera", "Ramos", "Molina", "Delgado", "Castro",
    "Ortega", "Núñez", "Ríos", "Mejía", "Salazar", "Cordero", "Estrada", "Sandoval",
    "Montes", "Carrillo", "Herrera", "Domínguez", "Vega", "Fuentes", "Ponce", "León",
    "Soto", "Peña", "Acosta", "Cortés", "Figueroa", "Espinoza", "Paredes", "Zamora",
    "Maldonado", "Velásquez", "Pacheco", "Mora", "Arias", "Cárdenas", "Valencia", "Ochoa"
]

def _full_name() -> str:
    return f"{random.choice(_FIRST_NAMES)} {random.choice(_LAST_NAMES)}"

def _status_desc(domain: str, code: str) -> str:
    mapping = {
        ("NFT","PENDING"): "NFT en revisión",
        ("NFT","APPROVED"): "NFT aprobado",
        ("NFT","REJECTED"): "NFT rechazado",
        ("AUCTION","ACTIVE"): "Subasta activa",
        ("AUCTION","COMPLETED"): "Subasta completada",
        ("AUCTION","CANCELLED"): "Subasta cancelada",
        ("FUNDS_RESERVATION","ACTIVE"): "Reserva activa",
        ("FUNDS_RESERVATION","RELEASED"): "Reserva liberada",
        ("FUNDS_RESERVATION","APPLIED"): "Reserva aplicada",
        ("USER_EMAIL","ACTIVE"): "Email activo",
        ("USER_EMAIL","INACTIVE"): "Email inactivo",
        ("EMAIL_OUTBOX","PENDING"): "Correo en cola",
        ("EMAIL_OUTBOX","SENT"): "Correo enviado",
        ("EMAIL_OUTBOX","FAILED"): "Fallo de envío",
        ("CURATION_DECISION","PENDING"): "Pendiente de revisión",
        ("CURATION_DECISION","APPROVED"): "Aprobado por curador",
        ("CURATION_DECISION","REJECTED"): "Rechazado por curador",
    }
    return mapping.get((domain, code), f"{domain}:{code}")

# ===============================
# Clase principal
# ===============================

class DataGenerator:
    def __init__(self, cfg: Optional[DataGenConfig] = None, *, verbose: bool = True):
        self.cfg = cfg or DataGenConfig()
        self.verbose = verbose
        _rng(self.cfg.seed)

        self.df_status: Optional[pd.DataFrame] = None
        self.df_role: Optional[pd.DataFrame] = None
        self.df_user: Optional[pd.DataFrame] = None
        self.df_auction_settings: Optional[pd.DataFrame] = None
        self.df_nft_settings: Optional[pd.DataFrame] = None

        # Placeholders
        self.df_userrole = None
        self.df_useremail = None
        self.df_wallet = None
        self.df_nft = None
        self.df_curation = None
        self.df_auction = None
        self.df_bid = None
        self.df_reservation = None
        self.df_ledger = None
        self.df_email_outbox = None

    # -------------------------------
    # Controlador del flujo/Pipeline
    # -------------------------------
    _PHASE_METHODS = {
        2: [
            "generate_status_catalog",
            "generate_roles",
            "generate_users",
            "generate_auction_settings",
            "generate_nft_settings",
        ],
        3: [
            "assign_user_roles",
            "generate_user_emails",
            "generate_wallets",
            "generate_nfts",
        ],
        4: [
            "generate_curation_reviews",
            "generate_auctions",
            "generate_bids",
            "settle_auctions_and_finance",
            "generate_email_outbox",
        ],
        5: [
            "to_sql_inserts",
            "write_sql_file",
        ],
    }

    def run_pipeline(
        self,
        phases: Tuple[int, ...] = (2, 3, 4, 5),
        *,
        strict: bool = True,
        export_sql_path: Optional[str] = None
    ) -> "DataGenerator":
        for phase in phases:
            methods = self._PHASE_METHODS.get(phase, [])
            if self.verbose:
                print(f"[Pipeline] Fase {phase} — métodos: {', '.join(methods) or '—'}")

            for m in methods:
                if m == "write_sql_file" and not export_sql_path:
                    if self.verbose:
                        print("  - skip write_sql_file (sin export_sql_path)")
                    continue

                if not hasattr(self, m) or not callable(getattr(self, m)):
                    if strict:
                        raise NotImplementedError(
                            f"El método requerido '{m}' para la fase {phase} aún no está implementado."
                        )
                    else:
                        if self.verbose:
                            print(f"  - omitiendo '{m}' (no implementado)")
                        continue

                if self.verbose:
                    print(f"  ✓ ejecutando {m}()")
                if m == "write_sql_file":
                    getattr(self, m)(export_sql_path)
                else:
                    getattr(self, m)()

        return self

    # ==========================
    # FASE 2: Métodos sin dependencias
    # ==========================
    def generate_status_catalog(self) -> pd.DataFrame:
        rows = []
        sid = 1
        for domain, codes in self.cfg.status_catalog.items():
            for code in codes:
                rows.append((sid, domain, code, _status_desc(domain, code)))
                sid += 1
        df = pd.DataFrame(rows, columns=["StatusId","Domain","Code","Description"])
        self.df_status = df
        if self.verbose:
            print(f"  - ops.Status: {len(df)} filas")
        return df

    def generate_roles(self, role_names: Optional[List[str]] = None) -> pd.DataFrame:
        names = role_names or list(self.cfg.role_probs.keys())
        unique_sorted = sorted(set(names))
        rows = [(i+1, n) for i, n in enumerate(unique_sorted)]
        df = pd.DataFrame(rows, columns=["RoleId","Name"])
        self.df_role = df
        if self.verbose:
            print(f"  - core.Role: {len(df)} filas → {', '.join(unique_sorted)}")
        return df

    def generate_users(self) -> pd.DataFrame:
        n = self.cfg.n_users
        rows = []
        for uid in range(1, n+1):
            rows.append((uid, _full_name(), _dt_between(self.cfg.start_date, self.cfg.end_date)))
        df = pd.DataFrame(rows, columns=["UserId","FullName","CreatedAtUtc"])
        self.df_user = df
        if self.verbose:
            print(f"  - core.[User]: {len(df)} usuarios")
        return df

    def generate_auction_settings(self) -> pd.DataFrame:
        rows = [(
            1,
            "ArteCrypto Auctions",
            round(self.cfg.suggested_price_eth_range[0], 4),
            int(self.cfg.default_auction_hours),
            int(self.cfg.min_bid_increment_pct)
        )]
        df = pd.DataFrame(rows, columns=[
            "SettingsID","CompanyName","BasePriceETH","DefaultAuctionHours","MinBidIncrementPct"
        ])
        self.df_auction_settings = df
        if self.verbose:
            print(f"  - auction.AuctionSettings: 1 fila")
        return df

    def generate_nft_settings(self) -> pd.DataFrame:
        """Genera configuración para NFTSettings (requerido por triggers)"""
        rows = [(
            1,  # SettingsID
            4096,  # MaxWidthPx
            512,   # MinWidthPx
            4096,  # MaxHeightPx
            512,   # MinHeightPx (nota: en DDL está MinHeigntPx - typo)
            10485760,  # MaxFileSizeBytes (10MB)
            1024,      # MinFileSizeBytes (1KB)
            self.cfg.start_date  # CreatedAtUtc
        )]
        df = pd.DataFrame(rows, columns=[
            "SettingsID","MaxWidthPx","MinWidthPx","MaxHeightPx","MinHeightPx",
            "MaxFileSizeBytes","MinFileSizeBytes","CreatedAtUtc"
        ])
        self.df_nft_settings = df
        if self.verbose:
            print(f"  - dbo.NFTSettings: 1 fila")
        return df

    # ==========================
    # FASE 3: Métodos dependientes Fase 2
    # ==========================

    def assign_user_roles(self) -> pd.DataFrame:
        """
        Asigna 1–3 roles por usuario respetando self.cfg.role_probs y evita duplicados (PK compuesta).
        AsignacionUtc se distribuye entre CreatedAtUtc del usuario y end_date.
        Requiere: self.df_user, self.df_role.
        """
        assert self.df_user is not None and self.df_role is not None, "Faltan users/roles"

        rng = np.random.default_rng(self.cfg.seed + 301)
        role_names = list(self.cfg.role_probs.keys())
        role_probs = np.array([self.cfg.role_probs[r] for r in role_names], dtype=float)
        role_probs = role_probs / role_probs.sum()

        # Mapa RoleName -> RoleId
        role_id_by_name = dict(self.df_role[["Name","RoleId"]].values)

        rows = []
        for uid, created_at in self.df_user[["UserId","CreatedAtUtc"]].itertuples(index=False):
            k_min, k_max = self.cfg.roles_per_user_range
            k = rng.integers(k_min, k_max+1)

            # muestreo ponderado sin reemplazo
            chosen = []
            available = role_names.copy()
            probs = role_probs.copy()
            for _ in range(k):
                probs = probs / probs.sum()
                pick_idx = rng.choice(len(available), p=probs)
                chosen.append(available[pick_idx])
                # quitar escogido
                del available[pick_idx]
                probs = np.delete(probs, pick_idx)
                if len(available) == 0:
                    break

            # con cierta probabilidad, permitir multirol; si no, forzar 1
            if rng.random() > self.cfg.multi_role_prob:
                chosen = chosen[:1]

            # construir filas (UserId, RoleId, AsignacionUtc)
            for name in sorted(set(chosen)):
                rid = role_id_by_name[name]
                asign_at = _dt_between(created_at, self.cfg.end_date)
                rows.append((uid, rid, asign_at))

        df = pd.DataFrame(rows, columns=["UserId","RoleId","AsignacionUtc"]).drop_duplicates(["UserId","RoleId"])
        self.df_userrole = df
        if self.verbose:
            by_user = df.groupby("UserId").size().mean()
            print(f"  - core.UserRole: {len(df)} filas (prom {by_user:.2f} roles/usuario)")
        return df

    def generate_user_emails(self) -> pd.DataFrame:
        """
        Genera 1–2 emails por usuario (configurable), único globalmente.
        Uno y solo uno IsPrimary=1 por usuario. VerifiedAtUtc ~85% si ACTIVE.
        Requiere: self.df_user, self.df_status (para dominios/estados).
        """
        assert self.df_user is not None and self.df_status is not None, "Faltan users/status"

        rng = np.random.default_rng(self.cfg.seed + 302)
        domains = self.cfg.email_domains
        status_codes = [c for c in self.cfg.status_catalog["USER_EMAIL"]]
        # Proporción razonable
        status_p = np.array([0.90 if c=="ACTIVE" else 0.10 for c in status_codes], dtype=float)
        status_p /= status_p.sum()

        def make_email(fullname: str, tag: int) -> str:
            parts = fullname.lower().replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u")
            parts = re.sub(r"[^a-z\s]", "", parts)
            first, *rest = parts.split()
            last = rest[-1] if rest else "user"
            return f"{first}.{last}{tag}@{rng.choice(domains)}"

        rows = []
        used = set()
        email_id = 1
        for uid, fullname, created_at in self.df_user[["UserId","FullName","CreatedAtUtc"]].itertuples(index=False):
            nmin, nmax = self.cfg.emails_per_user_range
            n = int(rng.integers(nmin, nmax+1))
            prim_index = int(rng.integers(0, n))

            for i in range(n):
                # generar único
                for attempt in range(100):
                    email = make_email(fullname, tag=int(rng.integers(0, 10000)))
                    if email not in used:
                        used.add(email)
                        break

                added_at = _dt_between(created_at, self.cfg.end_date)
                status = rng.choice(status_codes, p=status_p)
                is_primary = 1 if i == prim_index else 0
                verified_at = None
                if status == "ACTIVE":
                    # 85% verificados; si primario, ligeramente más probable
                    p_verify = 0.85 + (0.08 if is_primary else 0.0)
                    if rng.random() < min(p_verify, 0.98):
                        verified_at = _dt_between(added_at, self.cfg.end_date)

                rows.append((
                    email_id, uid, email, is_primary, added_at, verified_at, status
                ))
                email_id += 1

        df = pd.DataFrame(rows, columns=[
            "EmailId","UserId","Email","IsPrimary","AddedAtUtc","VerifiedAtUtc","StatusCode"
        ])
        self.df_useremail = df
        if self.verbose:
            active_ratio = df["StatusCode"].eq("ACTIVE").mean()
            print(f"  - core.UserEmail: {len(df)} filas (1 primario por usuario; ACTIVE≈{active_ratio:.0%})")
        return df

    def generate_wallets(self) -> pd.DataFrame:
        """
        Una wallet por usuario (UQ_Wallet_User). ReservedETH <= BalanceETH.
        Requiere: self.df_user.
        """
        assert self.df_user is not None, "Faltan users"

        rng = np.random.default_rng(self.cfg.seed + 303)
        rows = []
        wid = 1
        b_lo, b_hi = self.cfg.balance_eth_range
        r_lo, r_hi = self.cfg.reserved_eth_range

        for uid, created_at in self.df_user[["UserId","CreatedAtUtc"]].itertuples(index=False):
            balance = float(rng.uniform(b_lo, b_hi))
            reserved_cap = min(balance, r_hi)
            reserved = float(rng.uniform(r_lo, reserved_cap))
            updated_at = _dt_between(created_at, self.cfg.end_date)

            rows.append((wid, uid, round(balance, 8), round(reserved, 8), updated_at))
            wid += 1

        df = pd.DataFrame(rows, columns=["WalletId","UserId","BalanceETH","ReservedETH","UpdatedAtUtc"])
        self.df_wallet = df
        if self.verbose:
            print(f"  - core.Wallet: {len(df)} filas (Reserved<=Balance ok)")
        return df

    def generate_nfts(self) -> pd.DataFrame:
        """
        Genera NFTs. ArtistId prioriza usuarios con rol ARTIST. CurrentOwnerId=ArtistId al crear.
        StatusCode ~ {APPROVED,PENDING,REJECTED}. ApprovedAtUtc sólo si APPROVED.
        Requiere: self.df_user, self.df_userrole, self.df_role, self.df_status.
        """
        assert self.df_user is not None and self.df_status is not None, "Faltan users/status"
        assert self.df_userrole is not None and self.df_role is not None, "Faltan roles"

        rng = np.random.default_rng(self.cfg.seed + 304)

        # pool de artistas
        role_artist_id = int(self.df_role.query("Name=='ARTIST'")["RoleId"].iloc[0]) if "ARTIST" in set(self.df_role["Name"]) else None
        artist_users = set(self.df_userrole.query("RoleId==@role_artist_id")["UserId"].tolist()) if role_artist_id else set()

        if not artist_users:
            # fallback: todos los usuarios
            artist_users = set(self.df_user["UserId"].tolist())

        users_df = self.df_user.set_index("UserId")

        # estados válidos para NFT
        nft_statuses = [c for c in self.cfg.status_catalog["NFT"] if c in {"PENDING","APPROVED","REJECTED"}]
        p_map = {"APPROVED":0.65, "PENDING":0.20, "REJECTED":0.15}
        status_p = np.array([p_map[c] for c in nft_statuses], dtype=float)
        status_p /= status_p.sum()

        def rand_hash64():
            return "".join(rng.choice(list("0123456789abcdef"), size=64))

        rows = []
        nid = 1
        for _ in range(self.cfg.n_nfts):
            artist_id = int(rng.choice(list(artist_users)))
            created_at = _dt_between(users_df.loc[artist_id, "CreatedAtUtc"], self.cfg.end_date)

            name = f"Obra #{nid:04d}"
            descr = f"Obra generada para dataset ArteCrypto (ID {nid})."
            ctype = rng.choice(self.cfg.content_types)
            hcode = rand_hash64()
            fsize = int(rng.integers(60_000, 8_000_000))  # 60KB–8MB
            w = int(rng.integers(512, 4096))
            h = int(rng.integers(512, 4096))
            sugg = float(rng.uniform(*self.cfg.suggested_price_eth_range))

            status = rng.choice(nft_statuses, p=status_p)
            approved_at = _dt_between(created_at, self.cfg.end_date) if status == "APPROVED" else None

            row = (
                int(nid),
                int(artist_id),
                1,  # SettingsID
                int(artist_id),  # CurrentOwnerId
                str(name),
                str(descr),
                str(ctype),
                str(hcode),
                int(fsize),
                int(w),
                int(h),
                float(sugg),
                str(status),
                created_at,
                approved_at
            )
            rows.append(cast(tuple[Any, ...], row))
            nid += 1

        df = pd.DataFrame(rows, columns=[
            "NFTId","ArtistId","SettingsID","CurrentOwnerId","Name","Description","ContentType",
            "HashCode","FileSizeBytes","WidthPx","HeightPx","SuggestedPriceETH",
            "StatusCode","CreatedAtUtc","ApprovedAtUtc"
        ])
        self.df_nft = df
        if self.verbose:
            dist = df["StatusCode"].value_counts(normalize=True).to_dict()
            print(f"  - nft.NFT: {len(df)} filas (status ~ { {k:f'{v:.0%}' for k,v in dist.items()} })")
        return df

    # ==========================
    # FASE 4: Generación de curación, subastas, pujas y liquidaciones
    # ==========================

    def generate_curation_reviews(self) -> pd.DataFrame:
        """
        Genera decisiones de curación para NFTs.
        Requiere: self.df_nft, self.df_role, self.df_user, self.df_userrole
        Salida: self.df_curation
        """
        assert self.df_nft is not None and self.df_role is not None and self.df_user is not None, "Faltan nft/role/user"

        rng = np.random.default_rng(self.cfg.seed + 400)
        # curadores disponibles
        role_curator_id = int(self.df_role.query("Name=='CURATOR'")["RoleId"].iloc[0]) if "CURATOR" in set(self.df_role["Name"]) else None
        curators = set()
        if role_curator_id is not None and self.df_userrole is not None:
            curators = set(self.df_userrole.query("RoleId==@role_curator_id")["UserId"].tolist())
        if not curators:
            curators = set(self.df_user["UserId"].tolist())

        curation_codes = ["PENDING", "APPROVED", "REJECTED"]
        # Probabilidad: PENDING (20%), APPROVED (60%), REJECTED (20%)
        p = np.array([0.20, 0.60, 0.20])

        rows = []
        rid = 1
        # Crear reviews para todos los NFTs
        for nft_id, created_at, status in self.df_nft[["NFTId","CreatedAtUtc","StatusCode"]].itertuples(index=False):
            curator = int(rng.choice(list(curators)))
            started_at = _dt_between(created_at, self.cfg.end_date)
            
            # Decisión basada en el estado del NFT
            if status == "APPROVED":
                decision = "APPROVED"
                reviewed_at = _dt_between(started_at, self.cfg.end_date)
            elif status == "REJECTED":
                decision = "REJECTED"
                reviewed_at = _dt_between(started_at, self.cfg.end_date)
            else:  # PENDING
                decision = str(rng.choice(curation_codes, p=p/p.sum()))
                reviewed_at = _dt_between(started_at, self.cfg.end_date) if decision != "PENDING" else None
            
            comment = f"Revisión automática - Decisión: {decision}"
            rows.append((rid, int(nft_id), curator, decision, comment, started_at, reviewed_at))
            rid += 1

        df = pd.DataFrame(rows, columns=[
            "ReviewId","NFTId","CuratorId","DecisionCode","Comment","StartedAtUtc","ReviewedAtUtc"
        ])
        self.df_curation = df
        if self.verbose:
            print(f"  - admin.CurationReview: {len(df)} filas")
        return df

    def generate_auctions(self) -> pd.DataFrame:
        """
        Crea subastas para una fracción de NFTs aprobados.
        Requiere: self.df_nft, self.df_auction_settings
        Salida: self.df_auction
        """
        assert self.df_nft is not None and self.df_auction_settings is not None, "Faltan nft/auction_settings"

        rng = np.random.default_rng(self.cfg.seed + 410)
        # escoger NFTs elegibles (APPROVED)
        nft_pool = self.df_nft.query("StatusCode=='APPROVED'").copy()
        n_to_auction = int(round(len(nft_pool) * self.cfg.pct_nfts_in_auction))
        chosen = rng.choice(nft_pool["NFTId"].to_numpy(), size=max(0, n_to_auction), replace=False) if n_to_auction > 0 else np.array([], dtype=int)

        rows = []
        aid = 1
        settings = self.df_auction_settings.iloc[0]
        default_hours = int(settings["DefaultAuctionHours"])

        nft_idx = self.df_nft.set_index("NFTId")

        for nft_id in chosen:
            nft_row = nft_idx.loc[int(nft_id)]
            start = _dt_between(nft_row["ApprovedAtUtc"] or nft_row["CreatedAtUtc"], self.cfg.end_date)
            end = start + timedelta(hours=default_hours)
            
            # Determinar estado
            if end > self.cfg.end_date:
                status = "ACTIVE"
            else:
                status = rng.choice(["ACTIVE","COMPLETED","CANCELLED"], p=[0.10, 0.80, 0.10])

            # precio inicial
            base_price = float(nft_row["SuggestedPriceETH"])
            start_price = round(base_price * float(rng.uniform(0.8, 1.2)), 8)
            current_price = start_price

            rows.append((
                aid, 1, int(nft_id), start, end, float(start_price), float(current_price), None, status
            ))
            aid += 1

        df = pd.DataFrame(rows, columns=[
            "AuctionId","SettingsID","NFTId","StartAtUtc","EndAtUtc","StartingPriceETH","CurrentPriceETH","CurrentLeaderId","StatusCode"
        ])
        self.df_auction = df
        if self.verbose:
            print(f"  - auction.Auction: {len(df)} filas")
        return df

    def generate_bids(self) -> pd.DataFrame:
        """
        Genera pujas para cada subasta basada en una Poisson(lambda).
        Requiere: self.df_auction, self.df_user, self.df_userrole
        Salida: self.df_bid
        """
        assert self.df_auction is not None and self.df_user is not None, "Faltan auction/user"

        rng = np.random.default_rng(self.cfg.seed + 420)
        # bidders preferidos
        bidders = None
        if self.df_role is not None and self.df_userrole is not None:
            try:
                role_bidder_id = int(self.df_role.query("Name=='BIDDER'")["RoleId"].iloc[0])
                bidders = list(self.df_userrole.query("RoleId==@role_bidder_id")["UserId"].unique())
            except Exception:
                bidders = None
        if not bidders:
            bidders = list(self.df_user["UserId"].tolist())

        rows = []
        bid_id = 1
        
        nft_idx = self.df_nft.set_index("NFTId")

        for auction_id, settings_id, nft_id, start_at, end_at, start_price, current_price, current_leader, status in self.df_auction[[
            "AuctionId","SettingsID","NFTId","StartAtUtc","EndAtUtc","StartingPriceETH","CurrentPriceETH","CurrentLeaderId","StatusCode"
        ]].itertuples(index=False):
            # si estado CANCELLED -> 0 pujas
            if status == "CANCELLED":
                continue

            # obtener artista del NFT
            artist_id = int(nft_idx.loc[int(nft_id)]["ArtistId"])

            # número de pujas Poisson
            lam = float(self.cfg.bids_per_auction_lambda)
            n_bids = int(rng.poisson(lam))
            if n_bids == 0 and status == "ACTIVE":
                if rng.random() < 0.05:
                    n_bids = 1

            price = float(start_price)
            # generar tiempos ordenados
            if n_bids > 0:
                times = sorted([start_at + timedelta(seconds=int(rng.integers(0, max(1, int((end_at - start_at).total_seconds()))))) for _ in range(n_bids)])
                for t in times:
                    # elegir bidder distinto al artista
                    candidate = int(rng.choice(bidders))
                    attempts = 0
                    while candidate == artist_id and attempts < 10:
                        candidate = int(rng.choice(bidders))
                        attempts += 1

                    # incremento
                    min_inc = max(0.00000001, price * 0.05)
                    increment = float(rng.uniform(1.0, 3.0)) * min_inc
                    bid_amount = round(price + increment, 8)

                    rows.append((
                        bid_id, int(auction_id), candidate, bid_amount, t
                    ))
                    bid_id += 1
                    price = bid_amount

        df = pd.DataFrame(rows, columns=[
            "BidId","AuctionId","BidderId","AmountETH","PlacedAtUtc"
        ])
        self.df_bid = df
        if self.verbose:
            print(f"  - auction.Bid: {len(df)} filas")
        return df

    def settle_auctions_and_finance(self) -> pd.DataFrame:
        """
        Resuelve subastas completadas: determina ganador, crea reservas y ledger
        Requiere: self.df_auction, self.df_bid, self.df_wallet, self.df_nft
        Salida: self.df_reservation y self.df_ledger
        """
        assert self.df_auction is not None and self.df_nft is not None, "Faltan auction/nft"
        
        bids_df = self.df_bid if self.df_bid is not None else pd.DataFrame(columns=["BidId","AuctionId","BidderId","AmountETH","PlacedAtUtc"])

        rng = np.random.default_rng(self.cfg.seed + 430)
        rows_res = []
        rows_ledger = []
        res_id = 1
        ledger_id = 1

        auction_idx = self.df_auction.set_index("AuctionId")
        nft_idx = self.df_nft.set_index("NFTId")

        # Actualizar CurrentLeaderId y CurrentPriceETH en auctions
        for aid in self.df_auction["AuctionId"]:
            bids_for = bids_df.query("AuctionId==@aid")
            if not bids_for.empty:
                # último bid (mayor precio)
                bids_sorted = bids_for.sort_values(["AmountETH","PlacedAtUtc"], ascending=[False, True])
                winner_row = bids_sorted.iloc[0]
                self.df_auction.loc[self.df_auction.AuctionId==aid, "CurrentLeaderId"] = int(winner_row["BidderId"])
                self.df_auction.loc[self.df_auction.AuctionId==aid, "CurrentPriceETH"] = float(winner_row["AmountETH"])

        # Procesar subastas completadas
        completed_auctions = self.df_auction.query("StatusCode=='COMPLETED'").copy()

        for aid, row in completed_auctions.set_index("AuctionId").iterrows():
            bids_for = bids_df.query("AuctionId==@aid")
            if bids_for.empty:
                continue

            bids_sorted = bids_for.sort_values(["AmountETH","PlacedAtUtc"], ascending=[False, True])
            winner_row = bids_sorted.iloc[0]
            winner_id = int(winner_row["BidderId"])
            winning_amount = float(winner_row["AmountETH"])

            # crear reserva
            rows_res.append((
                res_id, int(aid), winner_id, round(winning_amount, 8), "APPLIED", row["EndAtUtc"]
            ))
            res_id += 1

            # ledger entries
            fee = round(winning_amount * 0.02, 8)
            seller_amount = round(winning_amount - fee, 8)
            nft_id = int(row["NFTId"])
            seller_id = int(nft_idx.loc[nft_id]["ArtistId"])

            # débito buyer
            rows_ledger.append((ledger_id, int(aid), winner_id, round(winning_amount,8), "DEBIT", row["EndAtUtc"]))
            ledger_id += 1
            # crédito seller
            rows_ledger.append((ledger_id, int(aid), seller_id, round(seller_amount,8), "CREDIT", row["EndAtUtc"]))
            ledger_id += 1

            # actualizar owner del NFT
            self.df_nft.loc[self.df_nft.NFTId==nft_id, "CurrentOwnerId"] = winner_id

        df_res = pd.DataFrame(rows_res, columns=["ReservationId","AuctionId","UserId","AmountETH","StateCode","CreatedAtUtc"])
        df_ledger = pd.DataFrame(rows_ledger, columns=["EntryId","AuctionId","UserId","AmountETH","EntryType","CreatedAtUtc"])

        self.df_reservation = df_res
        self.df_ledger = df_ledger
        if self.verbose:
            print(f"  - finance.FundsReservation: {len(df_res)} filas")
            print(f"  - finance.Ledger: {len(df_ledger)} filas")
        return df_res

    def generate_email_outbox(self) -> pd.DataFrame:
        """
        Genera emails para eventos del sistema
        Requiere: self.df_auction, self.df_useremail, self.df_curation
        Salida: self.df_email_outbox
        """
        assert self.df_auction is not None, "Faltan auction"

        rng = np.random.default_rng(self.cfg.seed + 440)
        out_rows = []
        eid = 1

        # helper: obtener email primario
        prim_emails = {}
        if self.df_useremail is not None:
            prim_emails = self.df_useremail.query("IsPrimary==1").set_index("UserId")["Email"].to_dict()

        nft_idx = self.df_nft.set_index("NFTId") if self.df_nft is not None else None

        # Emails de subastas
        for _, auc in self.df_auction.iterrows():
            nftid = int(auc["NFTId"])
            if nft_idx is not None and nftid in nft_idx.index:
                artist = int(nft_idx.loc[nftid]["ArtistId"])
                to_email = prim_emails.get(artist, None)
                if to_email:
                    subj = f"Subasta creada para NFT #{nftid}"
                    body = f"Tu NFT ha sido listado en subasta (Auction #{int(auc['AuctionId'])})."
                    out_rows.append((eid, artist, to_email, subj, body, "PENDING"))
                    eid += 1

        # Emails de curación
        if self.df_curation is not None:
            for _, cur in self.df_curation.iterrows():
                if cur["DecisionCode"] in ["APPROVED", "REJECTED"]:
                    nftid = int(cur["NFTId"])
                    if nft_idx is not None and nftid in nft_idx.index:
                        artist = int(nft_idx.loc[nftid]["ArtistId"])
                        to_email = prim_emails.get(artist, None)
                        if to_email:
                            decision = "aprobado" if cur["DecisionCode"] == "APPROVED" else "rechazado"
                            subj = f"NFT #{nftid} {decision}"
                            body = f"Tu NFT ha sido {decision} por el curador."
                            out_rows.append((eid, artist, to_email, subj, body, "PENDING"))
                            eid += 1

        df = pd.DataFrame(out_rows, columns=["EmailId","RecipientUserId","RecipientEmail","Subject","Body","StatusCode"])
        self.df_email_outbox = df
        if self.verbose:
            print(f"  - audit.EmailOutbox: {len(df)} filas")
        return df

    # ==========================
    # FASE 5: Exportación a SQL
    # ==========================

    def to_sql_inserts(self) -> Dict[str, List[str]]:
        """
        Convierte todos los DataFrames a sentencias INSERT de SQL
        Retorna: Dict con nombre de tabla -> lista de INSERTs
        """
        sql_statements = {}

        def df_to_inserts(df: pd.DataFrame, table_name: str, schema: str = "dbo") -> List[str]:
            if df is None or df.empty:
                return []
            
            inserts = []
            full_table = f"[{schema}].[{table_name}]"
            cols = ", ".join([f"[{c}]" for c in df.columns])
            
            for _, row in df.iterrows():
                values = []
                for val in row:
                    if pd.isna(val) or val is None:
                        values.append("NULL")
                    elif isinstance(val, (int, np.integer)):
                        values.append(str(val))
                    elif isinstance(val, (float, np.floating)):
                        values.append(f"{val:.8f}")
                    elif isinstance(val, datetime):
                        values.append(f"'{val.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}'")
                    else:
                        # string - escapar comillas simples
                        escaped = str(val).replace("'", "''")
                        values.append(f"N'{escaped}'")
                
                insert = f"INSERT INTO {full_table} ({cols}) VALUES ({', '.join(values)});"
                inserts.append(insert)
            
            return inserts

        # Generar INSERTs para cada tabla
        if self.df_status is not None:
            sql_statements["ops.Status"] = df_to_inserts(self.df_status, "Status", "ops")
        
        if self.df_role is not None:
            sql_statements["core.Role"] = df_to_inserts(self.df_role, "Role", "core")
        
        if self.df_user is not None:
            sql_statements["core.User"] = df_to_inserts(self.df_user, "User", "core")
        
        if self.df_nft_settings is not None:
            sql_statements["dbo.NFTSettings"] = df_to_inserts(self.df_nft_settings, "NFTSettings", "dbo")
        
        if self.df_auction_settings is not None:
            sql_statements["auction.AuctionSettings"] = df_to_inserts(self.df_auction_settings, "AuctionSettings", "auction")
        
        if self.df_userrole is not None:
            sql_statements["core.UserRole"] = df_to_inserts(self.df_userrole, "UserRole", "core")
        
        if self.df_useremail is not None:
            sql_statements["core.UserEmail"] = df_to_inserts(self.df_useremail, "UserEmail", "core")
        
        if self.df_wallet is not None:
            sql_statements["core.Wallet"] = df_to_inserts(self.df_wallet, "Wallet", "core")
        
        if self.df_nft is not None:
            sql_statements["nft.NFT"] = df_to_inserts(self.df_nft, "NFT", "nft")
        
        if self.df_curation is not None:
            sql_statements["admin.CurationReview"] = df_to_inserts(self.df_curation, "CurationReview", "admin")
        
        if self.df_auction is not None:
            sql_statements["auction.Auction"] = df_to_inserts(self.df_auction, "Auction", "auction")
        
        if self.df_bid is not None:
            sql_statements["auction.Bid"] = df_to_inserts(self.df_bid, "Bid", "auction")
        
        if self.df_reservation is not None:
            sql_statements["finance.FundsReservation"] = df_to_inserts(self.df_reservation, "FundsReservation", "finance")
        
        if self.df_ledger is not None:
            sql_statements["finance.Ledger"] = df_to_inserts(self.df_ledger, "Ledger", "finance")
        
        if self.df_email_outbox is not None:
            sql_statements["audit.EmailOutbox"] = df_to_inserts(self.df_email_outbox, "EmailOutbox", "audit")

        if self.verbose:
            total = sum(len(stmts) for stmts in sql_statements.values())
            print(f"  - Generados {total} INSERT statements para {len(sql_statements)} tablas")
        
        return sql_statements

    def write_sql_file(self, filepath: str) -> None:
        """
        Escribe todos los INSERTs a un archivo SQL
        """
        sql_statements = self.to_sql_inserts()
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write("-- =====================================================================================\n")
            f.write("-- SCRIPT DE INSERCIÓN DE DATOS - ArteCryptoAuctions\n")
            f.write(f"-- Generado: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("-- =====================================================================================\n\n")
            f.write("USE [ArteCryptoAuctions];\n")
            f.write("GO\n\n")
            f.write("SET NOCOUNT ON;\n")
            f.write("GO\n\n")
            
            # Orden de inserción (respetando FKs)
            table_order = [
                "ops.Status",
                "core.Role",
                "core.User",
                "dbo.NFTSettings",
                "auction.AuctionSettings",
                "core.UserRole",
                "core.UserEmail",
                "core.Wallet",
                "nft.NFT",
                "admin.CurationReview",
                "auction.Auction",
                "auction.Bid",
                "finance.FundsReservation",
                "finance.Ledger",
                "audit.EmailOutbox"
            ]
            
            for table in table_order:
                if table in sql_statements:
                    f.write(f"-- =====================================================================================\n")
                    f.write(f"-- {table}\n")
                    f.write(f"-- =====================================================================================\n")
                    f.write(f"PRINT 'Insertando datos en {table}...';\n")
                    f.write("GO\n\n")
                    
                    for stmt in sql_statements[table]:
                        f.write(stmt + "\n")
                    
                    f.write("\nGO\n\n")
            
            f.write("PRINT 'Inserción de datos completada exitosamente.';\n")
            f.write("GO\n")
        
        if self.verbose:
            print(f"  - Archivo SQL escrito: {filepath}")
