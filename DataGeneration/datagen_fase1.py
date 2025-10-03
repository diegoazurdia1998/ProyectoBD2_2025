# datagen_fase1.py
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Tuple, Optional

# ===============================
# FASE 1: Imports y Atributos
# ===============================

@dataclass
class DataGenConfig:
    """
    Configuración global del generador de datos.
    Esta fase solo define atributos; la lógica de generación se implementa en fases posteriores.
    """
    # Reproducibilidad y ventana temporal
    seed: int = 42
    start_date: datetime = datetime(2025, 6, 1)
    end_date: datetime   = datetime(2025, 10, 1)

    # Escala
    n_users: int = 200
    n_nfts: int = 600
    pct_nfts_in_auction: float = 0.60

    # Roles y multi-rol
    role_probs: Dict[str, float] = field(default_factory=lambda: {
        "ADMIN": 0.05, "ARTIST": 0.25, "CURATOR": 0.08, "BIDDER": 0.85
    })
    multi_role_prob: float = 0.35
    roles_per_user_range: Tuple[int, int] = (1, 3)

    # Emails
    emails_per_user_range: Tuple[int, int] = (1, 2)
    pct_primary_verified: float = 1.00
    email_domains: List[str] = field(default_factory=lambda: [
        "gmail.com", "outlook.com", "yahoo.com", "uni.edu.gt","correo.url.edu.gt"
    ])

    # Wallets
    balance_eth_range: Tuple[float, float] = (0.0, 20.0)
    reserved_eth_range: Tuple[float, float] = (0.0, 3.0)

    # NFT
    suggested_price_eth_range: Tuple[float, float] = (0.05, 5.0)
    content_types: List[str] = field(default_factory=lambda: [
        "image/png", "image/jpeg"
    ])

    # Subastas (según enunciado)
    default_auction_hours: int = 72
    min_bid_increment_pct: int = 5
    bids_per_auction_lambda: float = 6.0  # media Poisson

    # Catálogo de estados EXACTO al MERGE del usuario
    status_catalog: Dict[str, List[str]] = field(default_factory=lambda: {
        "NFT": ["PENDING","APPROVED","REJECTED","FINALIZED"],
        "AUCTION": ["ACTIVE","FINALIZED","CANCELED"],
        "FUNDS_RESERVATION": ["ACTIVE","RELEASED","APPLIED"],
        "USER_EMAIL": ["ACTIVE","INACTIVE"],
        "EMAIL_OUTBOX": ["PENDING","SENT","FAILED"],
        "CURATION_DECISION": ["APPROVE","REJECT"]
    })

class DataGenerator:
    """
    Clase principal. En Fase 1 solo define atributos y el controlador del flujo.
    Las implementaciones concretas de cada fase se agregarán después.
    """
    # Nombres de métodos por fase (convención)
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

    def __init__(self, cfg: Optional[DataGenConfig] = None, *, verbose: bool = True):
        self.cfg = cfg or DataGenConfig()
        self.verbose = verbose

        # DataFrames/estructuras por tabla (se llenarán en fases siguientes)
        self.df_status = None
        self.df_role = None
        self.df_user = None
        self.df_auction_settings = None
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
    def run_pipeline(
        self,
        phases: Tuple[int, ...] = (2, 3, 4, 5),
        *,
        strict: bool = True,
        export_sql_path: Optional[str] = None
    ) -> "DataGenerator":
        """
        Ejecuta las fases en orden y llama a los métodos de cada fase.
        - phases: fases a ejecutar (por defecto 2→5).
        - strict: si True, lanza error cuando un método no está implementado;
                  si False, lo omite mostrando una nota.
        - export_sql_path: si se indica, en la fase 5 intenta llamar a write_sql_file(path).
        """
        for phase in phases:
            methods = self._PHASE_METHODS.get(phase, [])
            if self.verbose:
                print(f"[Pipeline] Fase {phase} — métodos: {', '.join(methods) or '—'}")

            for m in methods:
                # Si es write_sql_file pero no se pasó export_sql_path, omitir
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

                # Ejecutar el método (con argumento si es write_sql_file)
                if self.verbose:
                    print(f"  ✓ ejecutando {m}()")
                if m == "write_sql_file":
                    getattr(self, m)(export_sql_path)
                else:
                    getattr(self, m)()

        return self
