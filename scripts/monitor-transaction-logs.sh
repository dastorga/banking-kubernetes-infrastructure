#!/bin/bash

# Monitor Transaction Logs - Monitoreo de logs de transacciones en tiempo real
# Script para ver los logs detallados de transacciones en el backend

echo "🏦 MONITOR DE LOGS DE TRANSACCIONES - BANKING SYSTEM"
echo "="*80
echo "Este script mostrará los logs detallados de transacciones en tiempo real"
echo "Presiona Ctrl+C para salir"
echo "="*80

# Función para obtener el nombre del pod del backend actual
get_backend_pod() {
    kubectl get pods -n banking-app -l app=banking-backend --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Verificar que el cluster esté disponible
echo "🔍 Verificando conexión al cluster..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Error: No se puede conectar al cluster de Kubernetes"
    echo "   Asegúrate de que minikube esté corriendo: minikube status"
    exit 1
fi

# Obtener el pod del backend
BACKEND_POD=$(get_backend_pod)

if [ -z "$BACKEND_POD" ]; then
    echo "❌ Error: No se encontró ningún pod del backend en ejecución"
    echo "   Verificando pods disponibles..."
    kubectl get pods -n banking-app
    exit 1
fi

echo "✅ Cluster conectado"
echo "🎯 Pod del backend encontrado: $BACKEND_POD"
echo ""

# Función para mostrar instrucciones
show_instructions() {
    echo "🚀 INSTRUCCIONES PARA PROBAR TRANSACCIONES:"
    echo ""
    echo "1. 💰 DEPÓSITO RÁPIDO:"
    echo "   - Ve a http://banking.local"
    echo "   - Haz clic en el botón 'Depósito' verde"
    echo "   - Verás logs detallados aquí"
    echo ""
    echo "2. 💸 RETIRO RÁPIDO:"
    echo "   - Haz clic en el botón 'Retiro' naranja"
    echo "   - Verás el proceso completo en los logs"
    echo ""
    echo "3. 📄 PAGO DE SERVICIOS:"
    echo "   - Haz clic en el botón 'Pago' azul"
    echo "   - Observa las validaciones y actualizaciones"
    echo ""
    echo "4. 💳 TRANSFERENCIA:"
    echo "   - Haz clic en 'Transferir' para ir al formulario"
    echo "   - Llena el formulario y envía"
    echo ""
    echo "="*80
    echo "📊 MONITOREANDO LOGS EN TIEMPO REAL..."
    echo "="*80
}

show_instructions

# Función para limpiar al salir
cleanup() {
    echo ""
    echo "🛑 Deteniendo monitoreo de logs..."
    echo "👋 ¡Gracias por usar el monitor de transacciones!"
    exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Monitorear logs en tiempo real con filtros para transacciones
echo "🔍 Siguiendo logs del pod: $BACKEND_POD"
echo ""

# Usar stern si está disponible, sino usar kubectl logs
if command -v stern > /dev/null 2>&1; then
    echo "📡 Usando stern para monitoreo avanzado..."
    stern -n banking-app banking-backend --since=1m --color=always \
        | grep -E "(TRANSACCIÓN|BALANCE|REDIS|DATABASE|ERROR|SUCCESS)" \
        | while read line; do
            echo "[$(date '+%H:%M:%S')] $line"
        done
else
    echo "📡 Usando kubectl logs para monitoreo..."
    kubectl logs -n banking-app -f "$BACKEND_POD" \
        | grep -E "(TRANSACCIÓN|BALANCE|REDIS|DATABASE|ERROR|SUCCESS)" \
        | while read line; do
            echo "[$(date '+%H:%M:%S')] $line"
        done
fi