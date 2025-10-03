
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
        "NFT": ["PENDING","APPROVED","REJECTED","FINALIZED"],
        "AUCTION": ["ACTIVE","FINALIZED","CANCELED"],
        "FUNDS_RESERVATION": ["ACTIVE","RELEASED","APPLIED"],
        "USER_EMAIL": ["ACTIVE","INACTIVE"],
        "EMAIL_OUTBOX": ["PENDING","SENT","FAILED"],
        "CURATION_DECISION": ["APPROVE","REJECT"]
    })

# ===============================
# Utilidades mínimas (Fase 2 las usa)
# ===============================

def _rng(seed: int):
    random.seed(seed)
    np.random.seed(seed)

def _dt_between(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = random.randrange(int(delta.total_seconds()))
    return start + timedelta(seconds=seconds)

_FIRST_NAMES = ["Diego","María","Juan","Lucía","Carlos","Ana","Pedro","Sofía","Luis","Elena",
                "Marco","Daniela","José","Camila","Jorge","Valeria","Andrés","Paola","Hugo","Fernanda"]
_LAST_NAMES  = ["Azurdia","García","Martínez","López","Hernández","Gómez","Pérez",
                "Ramírez","Flores","Torres","Díaz","Vásquez","Castillo","Ortiz","Morales",
                "Reyes","Cruz","Mendoza","Romero","Silva"]

def _full_name() -> str:
    return f"{random.choice(_FIRST_NAMES)} {random.choice(_LAST_NAMES)}"

def _status_desc(domain: str, code: str) -> str:
    mapping = {
        ("NFT","PENDING"): "NFT en revisión",
        ("NFT","APPROVED"): "NFT aprobado",
        ("NFT","REJECTED"): "NFT rechazado",
        ("NFT","FINALIZED"): "NFT finalizado",
        ("AUCTION","ACTIVE"): "Subasta activa",
        ("AUCTION","FINALIZED"): "Subasta finalizada",
        ("AUCTION","CANCELED"): "Subasta cancelada",
        ("FUNDS_RESERVATION","ACTIVE"): "Reserva activa",
        ("FUNDS_RESERVATION","RELEASED"): "Reserva liberada",
        ("FUNDS_RESERVATION","APPLIED"): "Reserva aplicada",
        ("USER_EMAIL","ACTIVE"): "Email activo",
        ("USER_EMAIL","INACTIVE"): "Email inactivo",
        ("EMAIL_OUTBOX","PENDING"): "Correo en cola",
        ("EMAIL_OUTBOX","SENT"): "Correo enviado",
        ("EMAIL_OUTBOX","FAILED"): "Fallo de envío",
        ("CURATION_DECISION","APPROVE"): "NFT aprobó la curación",
        ("CURATION_DECISION","REJECT"): "NFT no aprobó la curación",
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

        # Placeholders (fases siguientes)
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
            print(f"  - auction.AuctionSettings: 1 fila (CompanyName='ArteCrypto Auctions')")
        return df

    # ==========================
    # FASE 3: Métodos dependendientes Fase 2
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
    domains = ["gmail.com","outlook.com","proton.me","artecrypto.test"]
    status_codes = [c for c in self.cfg.status_catalog["USER_EMAIL"]]
    # Proporción razonable
    status_p = np.array([0.90 if c=="ACTIVE" else 0.10 for c in status_codes], dtype=float)
    status_p /= status_p.sum()

    def make_email(fullname: str, tag: int) -> str:
        parts = fullname.lower().replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u")
        parts = re.sub(r"[^a-z\s]", "", parts)
        first, *rest = parts.split()
        last = rest[-1] if rest else "user"
        return f"{first}.{last}+{tag}@{rng.choice(domains)}"

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
                email_id, uid, email, is_primary, added_at, verified_at,
                status,  # StatusCode
            ))
            email_id += 1

    df = pd.DataFrame(rows, columns=[
        "EmailId","UserId","Email","IsPrimary","AddedAtUtc","VerifiedAtUtc","StatusCode"
    ])
    self.df_useremail = df
    if self.verbose:
        primaries = int(df.query("IsPrimary==1").groupby("UserId").size().mean())
        print(f"  - core.UserEmail: {len(df)} filas (1 primario por usuario; ACTIVE≈{(df.StatusCode=='ACTIVE').mean():.0%})")
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
            1,
            int(artist_id),
            str(name),
            str(descr),
            str(ctype),
            str(hcode),
            int(fsize),
            int(w),
            int(h),
            float(sugg),
            str(status),
            created_at,  # datetime
            approved_at  # Optional[datetime]
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
