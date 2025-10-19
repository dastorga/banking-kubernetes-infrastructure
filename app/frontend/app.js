// Banking Digital - JavaScript Application

class BankingApp {
    constructor() {
        this.currentSection = 'dashboard';
        this.API_BASE = '/api';
        this.accounts = [];
        this.transactions = [];
        this.currentUser = null;
        
        this.init();
    }

    async init() {
        // Initialize app
        this.setupEventListeners();
        this.updateCurrentDate();
        await this.loadInitialData();
        this.hideLoading();
    }

    setupEventListeners() {
        // Navigation
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('nav-link')) {
                e.preventDefault();
                const section = e.target.dataset.section;
                this.navigateToSection(section);
            }
        });

        // Quick actions
        document.addEventListener('click', (e) => {
            if (e.target.closest('.action-btn')) {
                const action = e.target.closest('.action-btn').dataset.action;
                this.handleQuickAction(action);
            }
        });

        // Transaction form
        const transactionForm = document.getElementById('transactionForm');
        if (transactionForm) {
            transactionForm.addEventListener('submit', (e) => {
                e.preventDefault();
                this.handleTransaction();
            });
        }

        // Logout button
        const logoutBtn = document.getElementById('logoutBtn');
        if (logoutBtn) {
            logoutBtn.addEventListener('click', () => {
                this.logout();
            });
        }

        // Modal events
        this.setupModalEvents();

        // Filters
        const periodFilter = document.getElementById('periodFilter');
        const searchFilter = document.getElementById('searchFilter');
        
        if (periodFilter) {
            periodFilter.addEventListener('change', () => {
                this.filterTransactions();
            });
        }
        
        if (searchFilter) {
            searchFilter.addEventListener('input', () => {
                this.filterTransactions();
            });
        }
    }

    setupModalEvents() {
        const modal = document.getElementById('modal');
        const closeModal = document.getElementById('closeModal');
        const cancelModal = document.getElementById('cancelModal');
        const confirmModal = document.getElementById('confirmModal');

        if (closeModal) {
            closeModal.addEventListener('click', () => {
                this.hideModal();
            });
        }

        if (cancelModal) {
            cancelModal.addEventListener('click', () => {
                this.hideModal();
            });
        }

        if (modal) {
            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    this.hideModal();
                }
            });
        }

        if (confirmModal) {
            confirmModal.addEventListener('click', () => {
                this.confirmModalAction();
            });
        }
    }

    navigateToSection(section) {
        // Hide all sections
        document.querySelectorAll('.section').forEach(s => {
            s.classList.remove('active');
        });

        // Show target section
        const targetSection = document.getElementById(section);
        if (targetSection) {
            targetSection.classList.add('active');
        }

        // Update navigation
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });

        const activeLink = document.querySelector(`[data-section="${section}"]`);
        if (activeLink) {
            activeLink.classList.add('active');
        }

        this.currentSection = section;

        // Load section-specific data
        this.loadSectionData(section);
    }

    async loadSectionData(section) {
        switch (section) {
            case 'dashboard':
                await this.loadDashboardData();
                break;
            case 'accounts':
                await this.loadAccountsData();
                break;
            case 'transactions':
                await this.loadTransactionFormData();
                break;
            case 'history':
                await this.loadTransactionHistory();
                break;
            case 'profile':
                await this.loadProfileData();
                break;
        }
    }

    async loadInitialData() {
        try {
            // Simulate API calls with mock data for now
            await this.loadMockData();
        } catch (error) {
            console.error('Error loading initial data:', error);
            this.showToast('Error cargando datos iniciales', 'error');
        }
    }

    async loadMockData() {
        // Mock user data
        this.currentUser = {
            id: 1,
            name: 'Juan Pérez',
            email: 'juan.perez@gmail.com'
        };

        // Mock accounts
        this.accounts = [
            {
                id: 1,
                type: 'checking',
                name: 'Cuenta Corriente',
                balance: 15750.00,
                accountNumber: '****1234'
            },
            {
                id: 2,
                type: 'savings',
                name: 'Cuenta Ahorros',
                balance: 45230.50,
                accountNumber: '****5678'
            },
            {
                id: 3,
                type: 'credit',
                name: 'Tarjeta Crédito',
                balance: -1250.00,
                accountNumber: '****9012',
                creditLimit: 5000
            }
        ];

        // Mock transactions
        this.transactions = [
            {
                id: 1,
                type: 'transfer',
                description: 'Transferencia a María González',
                amount: -500.00,
                date: new Date(Date.now() - 86400000),
                account: 'Cuenta Corriente',
                category: 'expense'
            },
            {
                id: 2,
                type: 'deposit',
                description: 'Depósito salario',
                amount: 2500.00,
                date: new Date(Date.now() - 172800000),
                account: 'Cuenta Corriente',
                category: 'income'
            },
            {
                id: 3,
                type: 'payment',
                description: 'Pago servicios públicos',
                amount: -150.75,
                date: new Date(Date.now() - 259200000),
                account: 'Cuenta Corriente',
                category: 'expense'
            },
            {
                id: 4,
                type: 'transfer',
                description: 'Transferencia desde ahorros',
                amount: 1000.00,
                date: new Date(Date.now() - 345600000),
                account: 'Cuenta Corriente',
                category: 'income'
            }
        ];

        await this.updateDashboard();
    }

    async loadDashboardData() {
        await this.updateDashboard();
        await this.updateRecentTransactions();
    }

    async updateDashboard() {
        const totalBalance = this.accounts.reduce((sum, account) => sum + account.balance, 0);
        
        // Update balance cards
        document.getElementById('totalBalance').textContent = this.formatCurrency(totalBalance);
        
        const checkingAccount = this.accounts.find(acc => acc.type === 'checking');
        const savingsAccount = this.accounts.find(acc => acc.type === 'savings');
        const creditAccount = this.accounts.find(acc => acc.type === 'credit');

        if (checkingAccount) {
            document.getElementById('checkingBalance').textContent = this.formatCurrency(checkingAccount.balance);
        }

        if (savingsAccount) {
            document.getElementById('savingsBalance').textContent = this.formatCurrency(savingsAccount.balance);
        }

        if (creditAccount) {
            document.getElementById('creditBalance').textContent = this.formatCurrency(creditAccount.balance);
        }
    }

    async updateRecentTransactions() {
        const recentTransactions = this.transactions.slice(0, 4);
        const container = document.getElementById('recentTransactionsList');
        
        if (!container) return;

        container.innerHTML = recentTransactions.map(transaction => `
            <div class="transaction-item">
                <div class="transaction-info">
                    <div class="transaction-icon ${transaction.category}">
                        <i class="fas ${this.getTransactionIcon(transaction.type)}"></i>
                    </div>
                    <div class="transaction-details">
                        <h4>${transaction.description}</h4>
                        <p>${this.formatDate(transaction.date)} • ${transaction.account}</p>
                    </div>
                </div>
                <div class="transaction-amount ${transaction.amount > 0 ? 'positive' : 'negative'}">
                    ${this.formatCurrency(transaction.amount)}
                </div>
            </div>
        `).join('');
    }

    async loadAccountsData() {
        const container = document.getElementById('accountsList');
        if (!container) return;

        container.innerHTML = this.accounts.map(account => `
            <div class="account-card">
                <div class="account-type">${account.name}</div>
                <div class="account-balance">${this.formatCurrency(account.balance)}</div>
                <div class="account-number">${account.accountNumber}</div>
                <div class="account-actions">
                    <button class="account-btn" onclick="app.viewAccountDetails(${account.id})">
                        Ver Detalles
                    </button>
                    <button class="account-btn" onclick="app.transferFromAccount(${account.id})">
                        Transferir
                    </button>
                </div>
                ${account.creditLimit ? `<div class="credit-limit">Límite: ${this.formatCurrency(account.creditLimit)}</div>` : ''}
            </div>
        `).join('');
    }

    async loadTransactionFormData() {
        const fromAccountSelect = document.getElementById('fromAccount');
        if (!fromAccountSelect) return;

        fromAccountSelect.innerHTML = '<option value="">Seleccionar cuenta</option>' +
            this.accounts
                .filter(acc => acc.type !== 'credit')
                .map(account => `
                    <option value="${account.id}">
                        ${account.name} - ${this.formatCurrency(account.balance)}
                    </option>
                `).join('');
    }

    async loadTransactionHistory() {
        this.displayTransactions(this.transactions);
    }

    displayTransactions(transactions) {
        const container = document.getElementById('transactionHistory');
        if (!container) return;

        if (transactions.length === 0) {
            container.innerHTML = '<p>No se encontraron transacciones.</p>';
            return;
        }

        container.innerHTML = `
            <div class="transactions-list">
                ${transactions.map(transaction => `
                    <div class="transaction-item">
                        <div class="transaction-info">
                            <div class="transaction-icon ${transaction.category}">
                                <i class="fas ${this.getTransactionIcon(transaction.type)}"></i>
                            </div>
                            <div class="transaction-details">
                                <h4>${transaction.description}</h4>
                                <p>${this.formatDate(transaction.date)} • ${transaction.account}</p>
                            </div>
                        </div>
                        <div class="transaction-amount ${transaction.amount > 0 ? 'positive' : 'negative'}">
                            ${this.formatCurrency(transaction.amount)}
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
    }

    async loadProfileData() {
        if (this.currentUser) {
            document.getElementById('profileName').textContent = this.currentUser.name;
            document.getElementById('profileEmail').textContent = this.currentUser.email;
            document.getElementById('userName').textContent = this.currentUser.name;
        }
    }

    handleQuickAction(action) {
        switch (action) {
            case 'transfer':
                this.navigateToSection('transactions');
                break;
            case 'pay':
                this.showToast('Funcionalidad de pagos próximamente', 'warning');
                break;
            case 'deposit':
                this.showToast('Funcionalidad de depósitos próximamente', 'warning');
                break;
            case 'withdraw':
                this.showToast('Funcionalidad de retiros próximamente', 'warning');
                break;
        }
    }

    async handleTransaction() {
        const form = document.getElementById('transactionForm');
        const formData = new FormData(form);
        
        const transaction = {
            fromAccount: document.getElementById('fromAccount').value,
            toAccount: document.getElementById('toAccount').value,
            amount: parseFloat(document.getElementById('amount').value),
            type: document.getElementById('transactionType').value,
            description: document.getElementById('description').value || 'Transferencia'
        };

        // Validate form
        if (!this.validateTransaction(transaction)) {
            return;
        }

        // Show confirmation modal
        this.showTransactionConfirmation(transaction);
    }

    validateTransaction(transaction) {
        if (!transaction.fromAccount) {
            this.showToast('Selecciona una cuenta de origen', 'error');
            return false;
        }

        if (!transaction.toAccount) {
            this.showToast('Ingresa la cuenta destino', 'error');
            return false;
        }

        if (!transaction.amount || transaction.amount <= 0) {
            this.showToast('Ingresa un monto válido', 'error');
            return false;
        }

        const account = this.accounts.find(acc => acc.id == transaction.fromAccount);
        if (account && transaction.amount > account.balance) {
            this.showToast('Saldo insuficiente', 'error');
            return false;
        }

        return true;
    }

    showTransactionConfirmation(transaction) {
        const account = this.accounts.find(acc => acc.id == transaction.fromAccount);
        
        const modalTitle = document.getElementById('modalTitle');
        const modalBody = document.getElementById('modalBody');
        
        modalTitle.textContent = 'Confirmar Transferencia';
        modalBody.innerHTML = `
            <div class="confirmation-details">
                <h4>Detalles de la Transacción</h4>
                <p><strong>Cuenta Origen:</strong> ${account.name}</p>
                <p><strong>Cuenta Destino:</strong> ${transaction.toAccount}</p>
                <p><strong>Monto:</strong> ${this.formatCurrency(transaction.amount)}</p>
                <p><strong>Concepto:</strong> ${transaction.description}</p>
                <p><strong>Tipo:</strong> ${transaction.type}</p>
            </div>
        `;

        this.showModal();
        this.pendingTransaction = transaction;
    }

    async confirmModalAction() {
        if (this.pendingTransaction) {
            await this.processTransaction(this.pendingTransaction);
            this.hideModal();
            this.pendingTransaction = null;
        }
    }

    async processTransaction(transaction) {
        try {
            // Simulate API call
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Update local data (in a real app, this would come from the server)
            const account = this.accounts.find(acc => acc.id == transaction.fromAccount);
            if (account) {
                account.balance -= transaction.amount;
            }

            // Add to transactions
            const newTransaction = {
                id: this.transactions.length + 1,
                type: transaction.type,
                description: `${transaction.description} - ${transaction.toAccount}`,
                amount: -transaction.amount,
                date: new Date(),
                account: account.name,
                category: 'expense'
            };

            this.transactions.unshift(newTransaction);

            // Update dashboard
            await this.updateDashboard();

            // Clear form
            document.getElementById('transactionForm').reset();

            this.showToast('Transferencia realizada exitosamente', 'success');
            
        } catch (error) {
            console.error('Error processing transaction:', error);
            this.showToast('Error procesando la transferencia', 'error');
        }
    }

    filterTransactions() {
        const period = document.getElementById('periodFilter')?.value || '30';
        const search = document.getElementById('searchFilter')?.value.toLowerCase() || '';
        
        const periodDays = parseInt(period);
        const cutoffDate = new Date(Date.now() - (periodDays * 24 * 60 * 60 * 1000));

        let filtered = this.transactions.filter(transaction => {
            const matchesPeriod = transaction.date >= cutoffDate;
            const matchesSearch = search === '' || 
                transaction.description.toLowerCase().includes(search) ||
                transaction.account.toLowerCase().includes(search);
            
            return matchesPeriod && matchesSearch;
        });

        this.displayTransactions(filtered);
    }

    viewAccountDetails(accountId) {
        this.showToast('Funcionalidad de detalles próximamente', 'warning');
    }

    transferFromAccount(accountId) {
        this.navigateToSection('transactions');
        setTimeout(() => {
            const fromAccountSelect = document.getElementById('fromAccount');
            if (fromAccountSelect) {
                fromAccountSelect.value = accountId;
            }
        }, 100);
    }

    logout() {
        if (confirm('¿Estás seguro que deseas cerrar sesión?')) {
            // In a real app, clear tokens and redirect to login
            this.showToast('Sesión cerrada exitosamente', 'success');
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        }
    }

    // Utility methods
    formatCurrency(amount) {
        return new Intl.NumberFormat('es-ES', {
            style: 'currency',
            currency: 'EUR',
            minimumFractionDigits: 2
        }).format(amount);
    }

    formatDate(date) {
        return new Intl.DateTimeFormat('es-ES', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    getTransactionIcon(type) {
        const icons = {
            'transfer': 'fa-exchange-alt',
            'deposit': 'fa-plus-circle',
            'payment': 'fa-credit-card',
            'withdraw': 'fa-minus-circle'
        };
        return icons[type] || 'fa-circle';
    }

    updateCurrentDate() {
        const dateElement = document.getElementById('currentDate');
        if (dateElement) {
            const now = new Date();
            dateElement.textContent = new Intl.DateTimeFormat('es-ES', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            }).format(now);
        }
    }

    showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;

        const container = document.getElementById('toast-container');
        container.appendChild(toast);

        // Auto remove after 5 seconds
        setTimeout(() => {
            toast.remove();
        }, 5000);
    }

    showModal() {
        const modal = document.getElementById('modal');
        modal.classList.add('show');
    }

    hideModal() {
        const modal = document.getElementById('modal');
        modal.classList.remove('show');
    }

    hideLoading() {
        const loading = document.getElementById('loading');
        setTimeout(() => {
            loading.classList.add('hidden');
            setTimeout(() => {
                loading.style.display = 'none';
            }, 300);
        }, 1000);
    }

    // API methods (for future backend integration)
    async apiCall(endpoint, options = {}) {
        const url = `${this.API_BASE}${endpoint}`;
        const config = {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        };

        try {
            const response = await fetch(url, config);
            
            if (!response.ok) {
                throw new Error(`API Error: ${response.status}`);
            }

            return await response.json();
        } catch (error) {
            console.error('API call failed:', error);
            throw error;
        }
    }

    async checkApiHealth() {
        try {
            const response = await this.apiCall('/health');
            console.log('API Health:', response);
            return true;
        } catch (error) {
            console.warn('API not available, using mock data');
            return false;
        }
    }
}

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.app = new BankingApp();
});

// Service Worker registration for PWA functionality
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(registration => {
                console.log('SW registered: ', registration);
            })
            .catch(registrationError => {
                console.log('SW registration failed: ', registrationError);
            });
    });
}