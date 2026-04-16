import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from dash import Dash, dcc, html, Input, Output
import dash_bootstrap_components as dbc

# Загрузка данных
df = pd.read_csv('ecommerce_dataset_2000.csv')
df['order_date'] = pd.to_datetime(df['order_date'])
df['revenue'] = df['price'] * df['quantity']

# Инициализация приложения
app = Dash(__name__, external_stylesheets=[dbc.themes.BOOTSTRAP])

# Получение уникальных категорий
categories = sorted(df['category'].unique())

# Layout приложения
app.layout = dbc.Container([
    dbc.Row([
        dbc.Col(html.H1("E-commerce Dashboard", className="text-center mb-4"), width=12)
    ]),

    # Фильтры
    dbc.Row([
        dbc.Col([
            html.Label("Период:", className="fw-bold"),
            dcc.DatePickerRange(
                id='date-filter',
                start_date=df['order_date'].min(),
                end_date=df['order_date'].max(),
                display_format='DD.MM.YYYY',
                className="mb-3"
            )
        ], width=6),

        dbc.Col([
            html.Label("Категории:", className="fw-bold"),
            dcc.Dropdown(
                id='category-filter',
                options=[{'label': cat, 'value': cat} for cat in categories],
                value=categories,
                multi=True,
                placeholder="Выберите категории"
            )
        ], width=6)
    ], className="mb-4"),

    # KPI карточки
    dbc.Row([
        dbc.Col(dbc.Card([
            dbc.CardBody([
                html.H6("Общая выручка", className="text-muted"),
                html.H3(id='kpi-revenue', className="text-primary")
            ])
        ]), width=3),

        dbc.Col(dbc.Card([
            dbc.CardBody([
                html.H6("Средний чек", className="text-muted"),
                html.H3(id='kpi-avg-check', className="text-success")
            ])
        ]), width=3),

        dbc.Col(dbc.Card([
            dbc.CardBody([
                html.H6("Количество заказов", className="text-muted"),
                html.H3(id='kpi-orders', className="text-info")
            ])
        ]), width=3),

        dbc.Col(dbc.Card([
            dbc.CardBody([
                html.H6("Уникальных клиентов", className="text-muted"),
                html.H3(id='kpi-customers', className="text-warning")
            ])
        ]), width=3)
    ], className="mb-4"),

    # Графики
    dbc.Row([
        dbc.Col(dcc.Graph(id='revenue-by-category'), width=6),
        dbc.Col(dcc.Graph(id='revenue-dynamics'), width=6)
    ], className="mb-4"),

    dbc.Row([
        dbc.Col(dcc.Graph(id='top-customers'), width=6),
        dbc.Col(dcc.Graph(id='price-distribution'), width=6)
    ])
], fluid=True, className="p-4")


# Callback для обновления всех компонентов
@app.callback(
    [
        Output('kpi-revenue', 'children'),
        Output('kpi-avg-check', 'children'),
        Output('kpi-orders', 'children'),
        Output('kpi-customers', 'children'),
        Output('revenue-by-category', 'figure'),
        Output('revenue-dynamics', 'figure'),
        Output('top-customers', 'figure'),
        Output('price-distribution', 'figure')
    ],
    [
        Input('date-filter', 'start_date'),
        Input('date-filter', 'end_date'),
        Input('category-filter', 'value')
    ]
)
def update_dashboard(start_date, end_date, selected_categories):
    # Фильтрация данных
    filtered_df = df.copy()

    if start_date and end_date:
        filtered_df = filtered_df[
            (filtered_df['order_date'] >= start_date) &
            (filtered_df['order_date'] <= end_date)
        ]

    if selected_categories:
        filtered_df = filtered_df[filtered_df['category'].isin(selected_categories)]

    # Проверка на пустые данные
    if filtered_df.empty:
        empty_fig = go.Figure()
        empty_fig.add_annotation(
            text="Нет данных для отображения",
            xref="paper", yref="paper",
            x=0.5, y=0.5, showarrow=False,
            font=dict(size=16, color="gray")
        )
        empty_fig.update_layout(
            xaxis=dict(showgrid=False, showticklabels=False, zeroline=False),
            yaxis=dict(showgrid=False, showticklabels=False, zeroline=False)
        )

        return (
            "0 ₽", "0 ₽", "0", "0",
            empty_fig, empty_fig, empty_fig, empty_fig
        )

    # KPI расчеты
    total_revenue = filtered_df['revenue'].sum()
    avg_check = filtered_df.groupby('order_id')['revenue'].sum().mean()
    total_orders = filtered_df['order_id'].nunique()
    unique_customers = filtered_df['user_id'].nunique()

    # График 1: Выручка по категориям
    revenue_by_cat = filtered_df.groupby('category')['revenue'].sum().reset_index()
    revenue_by_cat = revenue_by_cat.sort_values('revenue', ascending=False)

    fig1 = px.bar(
        revenue_by_cat,
        x='category',
        y='revenue',
        title='Выручка по категориям',
        labels={'revenue': 'Выручка (₽)', 'category': 'Категория'},
        color='revenue',
        color_continuous_scale='Blues'
    )
    fig1.update_layout(showlegend=False)

    # График 2: Динамика выручки по дням
    revenue_by_date = filtered_df.groupby('order_date')['revenue'].sum().reset_index()

    fig2 = px.line(
        revenue_by_date,
        x='order_date',
        y='revenue',
        title='Динамика выручки по дням',
        labels={'revenue': 'Выручка (₽)', 'order_date': 'Дата'},
        markers=True
    )
    fig2.update_traces(line_color='#1f77b4')

    # График 3: Топ-10 клиентов
    top_customers = filtered_df.groupby('user_id')['revenue'].sum().reset_index()
    top_customers = top_customers.sort_values('revenue', ascending=False).head(10)

    fig3 = px.bar(
        top_customers,
        x='user_id',
        y='revenue',
        title='Топ-10 клиентов по сумме покупок',
        labels={'revenue': 'Сумма покупок (₽)', 'user_id': 'ID клиента'},
        color='revenue',
        color_continuous_scale='Greens'
    )
    fig3.update_layout(showlegend=False)

    # График 4: Распределение чека по категориям
    order_totals = filtered_df.groupby(['order_id', 'category'])['revenue'].sum().reset_index()

    fig4 = px.box(
        order_totals,
        x='category',
        y='revenue',
        title='Распределение чека по категориям',
        labels={'revenue': 'Сумма чека (₽)', 'category': 'Категория'},
        color='category'
    )

    # Форматирование KPI
    kpi_revenue = f"{total_revenue:,.0f} ₽".replace(',', ' ')
    kpi_avg = f"{avg_check:,.0f} ₽".replace(',', ' ')
    kpi_orders = f"{total_orders:,}".replace(',', ' ')
    kpi_customers = f"{unique_customers:,}".replace(',', ' ')

    return (
        kpi_revenue, kpi_avg, kpi_orders, kpi_customers,
        fig1, fig2, fig3, fig4
    )


if __name__ == '__main__':
    app.run(debug=True, port=8050)
