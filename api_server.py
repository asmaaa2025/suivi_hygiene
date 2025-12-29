from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import json
from datetime import datetime
import os

app = FastAPI(title="Suivi Hygiène API", version="1.0.0")

# Configuration CORS pour permettre les requêtes depuis l'émulateur
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modèles de données
class LoginRequest(BaseModel):
    email: str
    password: str

class LoginResponse(BaseModel):
    access: str
    token_type: str = "bearer"

class Appareil(BaseModel):
    id: int
    nom: str
    temp_min: float
    temp_max: float

class Temperature(BaseModel):
    id: int
    appareil: str
    temperature: float
    date: str
    remarque: Optional[str] = None

# Données en mémoire (en production, utilisez une base de données)
appareils_db = [
    {"id": 1, "nom": "Frigo", "temp_min": 2.0, "temp_max": 4.0},
    {"id": 2, "nom": "Congélateur", "temp_min": -25.0, "temp_max": -18.0},
    {"id": 3, "nom": "Chambre froide", "temp_min": 0.0, "temp_max": 4.0},
]

temperatures_db = [
    {"id": 1, "appareil": "Frigo", "temperature": 3.2, "date": "2024-01-15T08:30:00", "remarque": "Température normale"},
    {"id": 2, "appareil": "Congélateur", "temperature": -20.5, "date": "2024-01-15T08:25:00", "remarque": "Température normale"},
    {"id": 3, "appareil": "Chambre froide", "temperature": 2.8, "date": "2024-01-15T08:20:00", "remarque": "Température normale"},
]

# Test credentials (use environment variables in production)
TEST_CREDENTIALS = {
    os.getenv("API_TEST_USER", "admin"): os.getenv("API_TEST_PASSWORD", "admin123")
}

# Token d'authentification simple (en production, utilisez JWT)
current_token = None

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    global current_token
    if credentials.credentials != current_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return credentials.credentials

@app.post("/api/auth/login/", response_model=LoginResponse)
async def login(request: LoginRequest):
    global current_token
    
    if request.email in TEST_CREDENTIALS and TEST_CREDENTIALS[request.email] == request.password:
        # Générer un token simple (en production, utilisez JWT)
        current_token = f"token_{datetime.now().timestamp()}"
        return LoginResponse(access=current_token)
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects"
        )

@app.get("/api/appareils/", response_model=List[Appareil])
async def get_appareils(token: str = Depends(verify_token)):
    return appareils_db

@app.post("/api/appareils/", status_code=201)
async def create_appareil(appareil: Appareil, token: str = Depends(verify_token)):
    appareil_dict = appareil.dict()
    appareil_dict["id"] = len(appareils_db) + 1
    appareils_db.append(appareil_dict)
    return appareil_dict

@app.get("/api/temperatures/", response_model=List[Temperature])
async def get_temperatures(appareil: Optional[str] = None, token: str = Depends(verify_token)):
    if appareil:
        return [t for t in temperatures_db if t["appareil"] == appareil]
    return temperatures_db

@app.post("/api/temperatures/", status_code=201)
async def create_temperature(temperature: Temperature, token: str = Depends(verify_token)):
    temperature_dict = temperature.dict()
    temperature_dict["id"] = len(temperatures_db) + 1
    temperatures_db.append(temperature_dict)
    return temperature_dict

@app.delete("/api/temperatures/{temperature_id}/", status_code=204)
async def delete_temperature(temperature_id: int, token: str = Depends(verify_token)):
    global temperatures_db
    temperatures_db = [t for t in temperatures_db if t["id"] != temperature_id]
    return None

@app.get("/")
async def root():
    return {"message": "API Suivi Hygiène - Utilisez /docs pour la documentation"}

if __name__ == "__main__":
    import uvicorn
    print("🚀 Démarrage du serveur API Suivi Hygiène...")
    print("📱 L'API sera accessible sur: http://localhost:8000")
    print("📖 Documentation: http://localhost:8000/docs")
    print("🔑 Identifiants de test: admin / admin123")
    uvicorn.run(app, host="0.0.0.0", port=8000) 