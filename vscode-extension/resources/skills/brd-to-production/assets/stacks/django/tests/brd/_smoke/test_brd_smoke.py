"""brd-to-production phase 0 smoke tests for Django (pytest + pytest-django)."""
import pytest
from django.urls import reverse, NoReverseMatch


def test_TC_0_01_settings_load(settings):
    assert settings.INSTALLED_APPS


@pytest.mark.django_db
def test_TC_0_02_database_and_rollback(django_user_model):
    django_user_model.objects.create_user(username="BRDTEST-smoke", password="x")
    assert django_user_model.objects.filter(username="BRDTEST-smoke").count() == 1


@pytest.mark.django_db
def test_TC_0_03_admin_login_page(client):
    try:
        url = reverse("admin:login")
    except NoReverseMatch:
        pytest.skip("django.contrib.admin not installed")
    assert client.get(url).status_code == 200
