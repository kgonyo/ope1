#ifndef DB_H
#define DB_H

#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QtSql>
#include <QSqlDatabase>
#include <QSqlQueryModel>
#include <QSqlTableModel>
#include <QSqlRecord>
#include <QSqlResult>
#include <QSqlField>
#include <QHash>
#include <QCryptographicHash>

class APP_DB;

/**
 * @brief The GenericTableModel class
 * Used to create generic models for QML controls
 */
class GenericTableModel : public QSqlTableModel {
    Q_OBJECT
public:
    explicit GenericTableModel(APP_DB *parent=0, QString table_name="", QSqlDatabase db = QSqlDatabase());

    void setTable(QString tableName);

    QVariant data(const QModelIndex &index, int role) const;
    QHash<int, QByteArray> roleNames() const { return m_roleNames; }

private:
    void generateRoleNames();

    QHash<int, QByteArray> m_roleNames;

};



/**
 * @brief Controls DB access, deals with migration, and exposes models to QML
 *
 */
class APP_DB : public QObject
{
    Q_OBJECT
public:
    explicit APP_DB(QQmlApplicationEngine *parent = 0);

    QHash<QString, GenericTableModel *> _tables;
signals:

public slots:

    bool init_db();

    // == USER FUNCTIONS ==
    bool auth_student(QString user_name, QString password);


    // == RESOURCE FUNCTIONS ==
    bool add_resource(QString resource_name, QString resource_url, QString resource_description, int sort_order);

    GenericTableModel *getTable(QString table_name);
private:

    QSqlDatabase _db;


};

#endif // DB_H
