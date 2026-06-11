"""Envio de emails transacionais (recuperação de senha)."""
import logging
from email.message import EmailMessage

import aiosmtplib

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def send_password_reset_email(to_email: str, reset_token: str) -> None:
    settings = get_settings()
    message = EmailMessage()
    message["From"] = settings.email_from
    message["To"] = to_email
    message["Subject"] = "GlobalTranslate — Recuperação de senha"
    message.set_content(
        "Recebemos um pedido para repor a sua senha.\n\n"
        f"Use este código na aplicação: {reset_token}\n\n"
        "O código expira em 30 minutos. Se não fez este pedido, ignore este email."
    )

    if not settings.smtp_host:
        # Em desenvolvimento sem SMTP configurado, regista no log em vez de falhar
        logger.warning("SMTP não configurado; token de reset para %s: %s", to_email, reset_token)
        return

    await aiosmtplib.send(
        message,
        hostname=settings.smtp_host,
        port=settings.smtp_port,
        username=settings.smtp_user or None,
        password=settings.smtp_password or None,
        start_tls=True,
    )
