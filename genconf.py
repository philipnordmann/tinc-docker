
from argparse import ArgumentParser
from jinja2 import FileSystemLoader, Environment
from jinja2.utils import select_autoescape
import yaml
from ipaddress import IPv4Network, IPv4Address
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from yaml.dumper import SafeDumper
import os

free_addresses = list()

templates = [
    ('tinc-up', 0o744),
    ('tinc-down', 0o744), 
    ('tinc.conf', 0o644), 
    ('id_rsa.pub', 0o644), 
    ('rsa_key.priv', 0o600)
]


def str_presenter(dumper, data):
  if len(data.splitlines()) > 1:  # check for multiline string
    return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
  return dumper.represent_scalar('tag:yaml.org,2002:str', data)

def generate_config(name: str, clients: list, default_config: dict) -> None:

    if name in clients.keys():
        client = clients[name] if clients[name] else dict()
    else:
        client = dict()

    if 'ip' not in client.keys():
        global free_addresses
        client['ip'] = str(free_addresses.pop())
    
    if 'private_key' not in client.keys():
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048
        )
        public_key = private_key.public_key()

        client['private_key'] = str(private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        ), encoding='utf-8')
        client['public_key'] = str(public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.PKCS1,
        ), encoding='utf-8')

    clients[name] = client
    return clients

def configure(name: str, clients: dict, default_config: dict, base_path: str, templates_path: str) -> None:
    network = IPv4Network(default_config['subnet'])
    netmask = network.prefixlen

    path = f'{base_path}'

    os.makedirs(path + '/hosts', exist_ok=True)

    loader = FileSystemLoader(templates_path)
    env = Environment(loader=loader, autoescape=select_autoescape())

    for template_name, mode in templates:
        template = env.get_template(template_name + '.j2')
        with open(path + '/' + template_name, 'w') as jinja_file:
            jinja_file.write(template.render(name=name, client=clients[name], subnet=default_config['subnet'], netmask=netmask))
        os.chmod(path + '/' + template_name, mode)
    
    for client in clients.keys():
        template = env.get_template('client.j2')
        with open(path + f'/hosts/{client}', 'w') as jinja_file:
            jinja_file.write(template.render(name=client, client=clients[client], subnet=default_config['subnet'], netmask=netmask))

def get_config(path) -> list:
    with open(path) as file:
        config = yaml.load(file, Loader=yaml.SafeLoader)
    return (config['default'], config['clients'])

def save_config(data, path) -> None:
    with open(path, 'w') as file:
        yaml.dump(data, file, Dumper=SafeDumper)

def main() -> None:
    yaml.add_representer(str, str_presenter)
    yaml.representer.SafeRepresenter.add_representer(str, str_presenter)

    parser = ArgumentParser()
    parser.add_argument('--name', help="name of the config", type=str)
    parser.add_argument('--config', help="path to clients.yml", type=str)
    parser.add_argument('--generate', help="generates config", action='store_true', required=False)
    parser.add_argument('--configure', help="configures this instance to use the given config to dest path", type=str, required=False)
    parser.add_argument('--templates', help="path to templates dir", type=str, default="./templates")
    args = parser.parse_args()

    name = args.name
    config_path = args.config
    
    default_config, clients = get_config(config_path)

    global free_addresses

    network = IPv4Network(default_config['subnet'])
    client_ips = [ IPv4Address(clients[c]['ip']) for c in clients.keys() if clients[c] and 'ip' in clients[c].keys() ]
    free_addresses = list(set(network.hosts()) - set(client_ips))

    if args.generate or args.configure:
        clients = generate_config(name, clients, default_config)
        save_config({'default': default_config, 'clients': clients}, config_path)
        
    if args.configure:
        configure(name, clients, default_config, args.configure, args.templates)    


if __name__ == '__main__':
    main()