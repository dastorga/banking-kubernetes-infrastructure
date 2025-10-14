#!/bin/bash

# 🔍 Demo Simple: Flujo de Datos en Tiempo Real
# Los datos desde el frontend hasta los pods

echo "🚀 Demo: Siguiendo los datos desde Frontend → Backend → Base de Datos"
echo "=================================================================="

# Colores para mejor visualización
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar que los pods están funcionando
echo -e "${BLUE}1️⃣ Verificando que todos los pods estén activos...${NC}"
kubectl get pods -n banking-app --no-headers | while read pod ready status restarts age; do
    if [[ "$status" == "Running" ]]; then
        echo "   ✅ $pod está funcionando ($ready)"
    else
        echo "   ❌ $pod no está funcionando ($status)"
    fi
done

echo ""

# Obtener la URL del frontend
echo -e "${BLUE}2️⃣ Obteniendo URL del frontend...${NC}"
MINIKUBE_IP=$(minikube ip 2>/dev/null)
FRONTEND_PORT=$(kubectl get service banking-frontend -n banking-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
FRONTEND_URL="http://$MINIKUBE_IP:$FRONTEND_PORT"
echo "   🌐 Frontend disponible en: $FRONTEND_URL"

echo ""

# Función simple para mostrar logs en tiempo real
monitor_logs() {
    local component=$1
    local color=$2
    echo -e "${color}📋 Últimos logs de $component:${NC}"
    kubectl logs --tail=3 deployment/$component -n banking-app 2>/dev/null | sed 's/^/   /'
}

echo -e "${YELLOW}3️⃣ DEMO EN VIVO: Haciendo una petición y viendo el flujo${NC}"
echo ""

echo -e "${GREEN}   → Enviando petición al frontend...${NC}"
curl -s "http://banking.local/api/health" > /dev/null 2>&1 &
sleep 1

echo -e "${GREEN}   → Los datos pasaron por el frontend (Nginx):${NC}"
monitor_logs "banking-frontend" "$BLUE"
echo ""

echo -e "${GREEN}   → Nginx redirigió al backend (FastAPI):${NC}"
monitor_logs "banking-backend" "$BLUE" 
echo ""

echo -e "${GREEN}   → Verificando conexión a Redis:${NC}"
kubectl exec deployment/redis -n banking-app -- redis-cli ping 2>/dev/null | sed 's/^/   📍 Redis responde: /'
echo ""

echo -e "${GREEN}   → Verificando conexión a PostgreSQL:${NC}"
kubectl exec deployment/postgres -n banking-app -- pg_isready -U bankinguser 2>/dev/null | sed 's/^/   📍 PostgreSQL: /'
echo ""

echo -e "${YELLOW}4️⃣ PRUEBA INTERACTIVA: Vamos a hacer requests reales${NC}"
echo ""

# Hacer varias peticiones para generar tráfico
echo -e "${GREEN}   → Haciendo 5 peticiones seguidas...${NC}"
for i in {1..5}; do
    echo "      Request #$i"
    curl -s "http://banking.local/api/health" | head -c 50 | sed 's/^/        ✅ Respuesta: /'
    echo "..."
    sleep 1
done

echo ""
echo -e "${YELLOW}5️⃣ RESUMEN FINAL: Estado actual de los pods${NC}"
echo ""

# Mostrar logs finales de cada componente
monitor_logs "banking-frontend" "$BLUE"
echo ""
monitor_logs "banking-backend" "$BLUE"
echo ""

# Mostrar estadísticas de Redis
echo -e "${BLUE}📊 Estado de Redis:${NC}"
kubectl exec deployment/redis -n banking-app -- redis-cli info stats 2>/dev/null | grep -E "(total_commands_processed|total_connections_received)" | sed 's/^/   /'

echo ""

# Mostrar estadísticas de PostgreSQL
echo -e "${BLUE}📊 Estado de PostgreSQL:${NC}"
kubectl exec deployment/postgres -n banking-app -- psql -U bankinguser -d bankingdb -t -c "SELECT 'Conexiones activas: ' || count(*) FROM pg_stat_activity;" 2>/dev/null | sed 's/^/   /'

echo ""
echo -e "${GREEN}✅ Demo completada! Los datos viajaron:${NC}"
echo "   📱 Navegador/curl → 🌐 Frontend (Nginx) → ⚙️ Backend (FastAPI) → 🗄️ Bases de Datos"
echo ""
echo -e "${YELLOW}💡 Para ver esto en tiempo real, ejecuta en terminales separadas:${NC}"
echo "   kubectl logs -f deployment/banking-frontend -n banking-app"
echo "   kubectl logs -f deployment/banking-backend -n banking-app"
echo "   kubectl exec deployment/redis -n banking-app -- redis-cli monitor"