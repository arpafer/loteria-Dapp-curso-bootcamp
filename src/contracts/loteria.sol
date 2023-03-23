// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loteria is ERC20, Ownable {

   //=======================================
   // Gestión de los tokens
   //=======================================

   // Dirección del contrato NFT del proyecto
   address public nft;

   constructor() ERC20("Loteria", "LAP") {
      _mint(address(this), 1000);
      nft = address(new mainERC721());
   }

   // Ganador del premio de la loteria
   address public ganador;

   // Registro del usuario
   mapping(address => address) public usuarioContract;

   // Precio de los tokens
   function precioTokens(uint256 _numTokens) internal pure returns (uint256) {
      return _numTokens * (1 ether);
   }

   // visualización del balance de tokens ERC20 de un usuario
   function balanceTokens(address _account) public view returns (uint256) {
       return balanceOf(_account);
   }

   // visualización del balance de tokens ERC20 del smartcontract
   function balanceTokensSC() public view returns (uint256) {
       return balanceOf(address(this));
   }

   // Visualización del balance de ethers del Smart Contract
   // 1 ether -> 10^18
   function balanceEthersSC() public view returns (uint256) {
       return address(this).balance / 10**18;
   }

   function mint(uint256 _numTokens) public onlyOwner() {
       _mint(address(this), _numTokens);
   }

   // Registro de usuarios
   function registrar() internal {
      address addrPersonalContract = address(new BoletosNFTs(msg.sender, address(this), nft));
      usuarioContract[msg.sender] = addrPersonalContract;
   }

   // Información de un usuario
   function userInfo(address _account) public view returns (address) {
       return usuarioContract[_account];
   }

   // compra de tokens ERC20
   function compraTokens(uint256 _numTokens) public payable {
       if (usuarioContract[msg.sender] == address(0)) {
           registrar();
       }
       // Establecimiento del coste de los tokens a comprar
       uint256 coste = precioTokens(_numTokens);
       // Evaluación del dinero que el cliente para por los tokens
       require(msg.value >= coste, "Compra menos tokens o paga con mas ethers");
       // Obtención del número de tokens disponibles
       uint256 balanceTokensDisponibles = balanceTokensSC();
       require(_numTokens <= balanceTokensDisponibles, "Compra un numero menor de tokens");
       // Devolución del dinero sobrante
       uint256 returnValue = msg.value - coste;
       // El Smart contract devuelve la cantidad restante
       payable(msg.sender).transfer(returnValue);
       // Envío de los tokens al cliente/usuario
       _transfer(address(this), msg.sender, _numTokens);
   }

   // devolución de tokens al Smart Contract
   function devolverTokens(uint _numTokens) public payable {
       // El numero de tokens debe ser mayor a 0
       require(_numTokens > 0, "Necesitas devolver un numero de tokens mayor a 0");
       // el usuario debe acreditar tener los tokens que quiere devolver
       require(_numTokens <= balanceTokens(msg.sender), "No tienes los tokens que deseas devolver");
       // El usuario transfiere los tokens al smart contract
       _transfer(msg.sender, address(this), _numTokens);
       // El smart contract envía los ethers al usuario
       payable(msg.sender).transfer(precioTokens(_numTokens));
   }

   // ====================================================
   // Gestión de la lotería
   // ====================================================

   // Precio del boleto de lotería (en tokens ERC20)
   uint public precioBoleto = 5;
   // Relación: persona que compra los boletos --> el número de los boletos
   mapping(address => uint[]) addressPersonaBoletos;
   // Relación: boleto => ganador
   mapping(uint => address) ADNBoleto;
   // Numero aleatorio
   uint randNonce = 0;
   // Boletos de la lotería comprados
   uint[] boletosComprados;

   // compra de boletos de lotería
   function comprarBoleto(uint _numBoletos) public {
       uint256 precioTotal = _numBoletos * precioBoleto;
       require(precioTotal <= balanceTokens(msg.sender), "No tienes tokens suficientes");
       _transfer(msg.sender, address(this), precioTotal);
       _generarBoletoAleatorio(_numBoletos);      
   }

   /* En random se genera aleatoriamente un número de lotería entre 0 y 9999.
      A continuación se guarda en la lista de boletos comprados, y también en la lista de
      boletos comprados por el usuario. Finalmente se genera el token NFT correspondiente al boleto
   */
   function _generarBoletoAleatorio(uint _numBoletos) private {       
       for (uint i = 0; i < _numBoletos; i++) {
           uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000;
           randNonce++;    
           addressPersonaBoletos[msg.sender].push(random);
           boletosComprados.push(random);
           ADNBoleto[random] = msg.sender;
           BoletosNFTs(usuarioContract[msg.sender]).mintBoleto(msg.sender, random);       
       }       
   }

   function viewBoletos(address _owner) public view returns(uint[] memory) {
      return addressPersonaBoletos[_owner];
   }

   // Generación del ganador de la lotería
   function generarGanador() public onlyOwner {
       uint longitud = boletosComprados.length;
       // Verificación de la compra de mas de 1 boleto
       require(longitud > 0, "No hay boletos comprados");       
       // Elección aleatoria de un numero entre: [0-longitud]
       uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % longitud);
       // Selección del número aleatorio
       uint eleccion = boletosComprados[random];
       ganador = ADNBoleto[eleccion];
       // Envío del 95% del premio de lotería al ganador
       payable(ganador).transfer(address(this).balance * 95 / 100);
       // Envío del 5% del premio de lotería al owner
       payable(owner()).transfer(address(this).balance * 5 / 100);
   }
}

// Contrato principal de gestión de los tokens NFT
contract mainERC721 is ERC721 {

    address public direccionLoteria;

    constructor() ERC721("Loteria", "STE") {
        direccionLoteria = msg.sender;
    }

    // Creación de NFTs
    function safeMint(address _owner, uint256 _idBoleto) public {        
        require(msg.sender == Loteria(direccionLoteria).userInfo(_owner), "No tiene permisos para ejecutar esta funcion");
        _safeMint(_owner, _idBoleto);
    }
}

contract BoletosNFTs {

    // Datos relevantes del propietario
    struct Owner {
       address direccionPropietario;
       address contratoPadre;
       address contratoNFT;
       address contratoUsuario;
    }
    Owner public propietario;

    constructor(address _owner, address _mainContract, address _nftContract) {
       propietario = Owner(_owner, _mainContract, _nftContract, address(this));
    }

    // conversión de los números de los boletos de lotería
    function mintBoleto(address _propietario, uint _boleto) public {
        require(propietario.contratoPadre == msg.sender, "No tiene permisos para ejecutar esta funcion");
        mainERC721(propietario.contratoNFT).safeMint(_propietario, _boleto);
    }
}